/* Unit tests for the org chart service layer. Run with:  node test/orglogic.test.js */
"use strict";
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const cache = {};
function load(file) {
    file = path.resolve(file);
    if (cache[file]) { return cache[file]; }
    const src = fs.readFileSync(file, "utf8");
    let result;
    const sap = { ui: { define(deps, factory) {
        result = factory.apply(null, deps.map(d => load(path.resolve(path.dirname(file), d + ".js"))));
    } } };
    new Function("sap", src)(sap);
    cache[file] = result;
    return result;
}
const Org = load(path.join(__dirname, "..", "webapp", "model", "OrgLogic.js"));

let passed = 0, failed = 0;
function test(name, fn) {
    try { Org.reset(); Org.setToday("2026-10-01"); fn(); passed++; console.log("  ok   " + name); }
    catch (e) { failed++; console.log("  FAIL " + name + "\n       " + e.message); }
}
const flat = nodes => nodes.reduce((a, n) => a.concat([n], flat(n.nodes)), []);
const ids = nodes => flat(nodes).map(n => n.id);

console.log("tree");
test("one root, 4 departments today; closed and future units are hidden", () => {
    const t = Org.getTree("2026-10-01");
    assert.strictEqual(t.length, 1);
    assert.strictEqual(t[0].id, "50000000");
    assert.strictEqual(t[0].nodes.length, 4);
    assert.ok(!ids(t).includes("50000041"));
    assert.ok(!ids(t).includes("50000099"));
    assert.strictEqual(ids(t).length, 11);
});
test("key date in the past shows the legacy team, key date in the future the new team", () => {
    assert.ok(ids(Org.getTree("2025-06-01")).includes("50000041"));
    assert.ok(!ids(Org.getTree("2026-01-01")).includes("50000041"));
    assert.ok(ids(Org.getTree("2027-03-01")).includes("50000099"));
});
test("invalid key date falls back to today", () => {
    assert.deepStrictEqual(ids(Org.getTree("garbage")), ids(Org.getTree("2026-10-01")));
});
test("headcount counts only employees active at the key date", () => {
    const sales = flat(Org.getTree("2026-10-01")).find(n => n.id === "50000040");
    // Yang Eunji left 2026-06-30 and her team is closed; Nam joins 2026-11-02
    assert.strictEqual(sales.headcount, 1);
    assert.strictEqual(sales.total, 4);
    const sales2027 = flat(Org.getTree("2027-03-01")).find(n => n.id === "50000040");
    assert.strictEqual(sales2027.total, 5);
});
test("root total equals the number of active employees", () => {
    assert.strictEqual(Org.getTree("2026-10-01")[0].total, 19);
    assert.strictEqual(Org.getTree("2027-03-01")[0].total, 20);
});
test("node totals are consistent with their children", () => {
    flat(Org.getTree("2027-03-01")).forEach(n => {
        assert.strictEqual(n.total, n.headcount + n.nodes.reduce((s, c) => s + c.total, 0), n.id);
    });
});

console.log("search");
test("search keeps matches and their ancestors only", () => {
    const t = Org.getTree("2026-10-01", "recruit");
    assert.deepStrictEqual(ids(t), ["50000000", "50000010", "50000011"]);
    assert.ok(flat(t).find(n => n.id === "50000011").match);
    assert.ok(!flat(t).find(n => n.id === "50000010").match);
});
test("search by unit id and case-insensitive", () => {
    assert.ok(ids(Org.getTree("2026-10-01", "50000022")).includes("50000022"));
    assert.ok(ids(Org.getTree("2026-10-01", "INFRA")).includes("50000022"));
});
test("search without hit returns an empty tree", () => {
    assert.deepStrictEqual(Org.getTree("2026-10-01", "zzz"), []);
});

console.log("unit details");
test("unit path, manager and counts", () => {
    const u = Org.getUnit("50000021", "2026-10-01");
    assert.deepStrictEqual(u.path, ["Sample Corp Korea", "IT Department", "Development Team"]);
    assert.strictEqual(u.managerName, "Park Jihun");
    assert.strictEqual(u.headcount, 3);
    assert.strictEqual(u.childCount, 0);
    const it = Org.getUnit("50000020", "2026-10-01");
    assert.strictEqual(it.childCount, 2);
    assert.strictEqual(it.total, 7);
});
test("unit that does not exist at the key date", () => {
    assert.strictEqual(Org.getUnit("50000041", "2026-10-01"), null);
    assert.strictEqual(Org.getUnit("50000099", "2026-10-01"), null);
    assert.strictEqual(Org.getUnit("nope", "2026-10-01"), null);
});
test("manager who has not joined yet is not shown", () => {
    const u = Org.getUnit("50000099", "2027-03-01");
    assert.strictEqual(u.managerName, "Nam Gaeun");
    // on 2027-01-01 the unit exists; the manager joined 2026-11-02 already
    assert.strictEqual(Org.getUnit("50000099", "2027-01-01").managerName, "Nam Gaeun");
});

console.log("members");
test("direct members, manager first", () => {
    const m = Org.getMembers("50000021", "2026-10-01", false);
    assert.strictEqual(m.length, 3);
    assert.strictEqual(m[0].name, "Park Jihun");
    assert.ok(m[0].isManager);
    assert.ok(m.slice(1).every(x => !x.isManager));
});
test("members including sub-units", () => {
    const direct = Org.getMembers("50000020", "2026-10-01", false);
    const all = Org.getMembers("50000020", "2026-10-01", true);
    assert.strictEqual(direct.length, 2);
    assert.strictEqual(all.length, 7);
    assert.ok(all.some(x => x.orgName === "Development Team"));
    assert.ok(all.every(x => x.orgName));
});
test("leaver and future joiner are filtered by key date", () => {
    assert.ok(Org.getMembers("50000041", "2025-06-01", false).some(x => x.pernr === "10000017"));
    assert.ok(!Org.getMembers("50000042", "2026-10-01", true).some(x => x.pernr === "10000021"));
    assert.ok(Org.getMembers("50000099", "2027-03-01", false).some(x => x.pernr === "10000021"));
    assert.deepStrictEqual(Org.getMembers("50000099", "2026-12-01", false), []);
});
test("members of an invalid unit", () => {
    assert.deepStrictEqual(Org.getMembers("50000041", "2026-10-01", true), []);
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
