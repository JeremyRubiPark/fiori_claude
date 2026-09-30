/* Unit tests for the service layer. Run with:  node test/palogic.test.js */
"use strict";
const fs = require("fs");
const path = require("path");
const assert = require("assert");

// minimal sap.ui.define shim so the AMD modules can run in Node
const cache = {};
function load(file) {
    file = path.resolve(file);
    if (cache[file]) { return cache[file]; }
    const src = fs.readFileSync(file, "utf8");
    let result;
    const sap = { ui: { define(deps, factory) {
        const args = deps.map(d => load(path.resolve(path.dirname(file), d + ".js")));
        result = factory.apply(null, args);
    } } };
    new Function("sap", src)(sap);
    cache[file] = result;
    return result;
}

const base = path.join(__dirname, "..", "webapp", "model");
const IT = load(path.join(base, "infotypes.js"));
const PA = load(path.join(base, "PALogic.js"));
const FOREVER = IT.FOREVER;

let passed = 0, failed = 0;
function test(name, fn) {
    try { PA.reset(); PA.setToday("2026-10-01"); fn(); passed++; console.log("  ok   " + name); }
    catch (e) { failed++; console.log("  FAIL " + name + "\n       " + e.message); }
}
const codes = r => (r.errors || []).map(e => e.code);
const mcodes = r => (r.messages || []).map(e => e.code);

/** checks time constraints for every infotype of one employee */
function checkConsistency(pernr) {
    IT.INFOTYPES.forEach(def => {
        const all = PA.getRecords(pernr, def.id, { period: "all" });
        const groups = {};
        all.forEach(r => { (groups[r.subty] = groups[r.subty] || []).push(r); });
        Object.keys(groups).forEach(s => {
            const l = groups[s].slice().sort((a, b) => a.begda < b.begda ? -1 : 1);
            l.forEach(r => assert(r.begda <= r.endda, `${pernr}/${def.id}: begda>endda ${r.begda}..${r.endda}`));
            for (let i = 1; i < l.length; i++) {
                assert(l[i].begda > l[i - 1].endda, `${pernr}/${def.id}/${s}: overlap ${l[i - 1].endda} vs ${l[i].begda}`);
                if (def.tc === "1") {
                    assert.strictEqual(PA.addDays(l[i - 1].endda, 1), l[i].begda, `${pernr}/${def.id}: gap ${l[i - 1].endda} -> ${l[i].begda}`);
                }
            }
            if (def.tc === "1") {
                assert.strictEqual(l[l.length - 1].endda, FOREVER, `${pernr}/${def.id}: last record must end ${FOREVER}`);
            }
        });
    });
}

console.log("seed data");
test("all employees satisfy their time constraints", () => {
    PA.searchEmployees({}).forEach(e => checkConsistency(e.pernr));
});
test("six employees, sorted by personnel number", () => {
    const l = PA.searchEmployees({});
    assert.strictEqual(l.length, 6);
    assert.deepStrictEqual(l.map(e => e.pernr), ["10000001", "10000002", "10000003", "10000004", "10000005", "10000006"]);
});

console.log("search / header");
test("search by name, both orders, case-insensitive", () => {
    assert.strictEqual(PA.searchEmployees({ name: "hong" }).length, 1);
    assert.strictEqual(PA.searchEmployees({ name: "gildong hong" }).length, 1);
    assert.strictEqual(PA.searchEmployees({ name: "ZZZ" }).length, 0);
});
test("search by personnel number part and org unit", () => {
    assert.strictEqual(PA.searchEmployees({ pernr: "100000" }).length, 6);
    assert.strictEqual(PA.searchEmployees({ pernr: "10000003" }).length, 1);
    assert.deepStrictEqual(PA.searchEmployees({ orgeh: "50000020" }).map(e => e.pernr), ["10000002", "10000004"].concat([]).sort().filter(p => p !== "10000001" ));
});
test("header depends on the key date", () => {
    assert.strictEqual(PA.getEmployee("10000001", "2022-01-01").plansText, "IT Architect");
    assert.strictEqual(PA.getEmployee("10000001", "2026-10-01").plansText, "HR Manager");
    assert.strictEqual(PA.getEmployee("10000001", "2016-01-01").plansText, "Software Engineer");
});
test("leaver has status Withdrawn; future hire falls back to first record", () => {
    assert.strictEqual(PA.getEmployee("10000005").statusText, "Withdrawn");
    assert.strictEqual(PA.getEmployee("10000005").statusState, "Error");
    const f = PA.getEmployee("10000006");
    assert.strictEqual(f.fullName, "Jung Sunghyun");
    assert.strictEqual(f.entryDate, "2027-01-04");
});
test("unknown personnel number", () => assert.strictEqual(PA.getEmployee("99999999"), null));

console.log("records / period");
test("current period returns only valid records, all returns history", () => {
    assert.strictEqual(PA.getRecords("10000001", "0001", { period: "current" }).length, 1);
    assert.strictEqual(PA.getRecords("10000001", "0001", { period: "all" }).length, 3);
    const all = PA.getRecords("10000001", "0001", { period: "all", keyDate: "2021-01-01" });
    assert.deepStrictEqual(all.map(r => r._valid), [false, true, false]); // newest first
});
test("0006 current shows every subtype valid at the key date", () => {
    const l = PA.getRecords("10000003", "0006", { period: "current" });
    assert.deepStrictEqual(l.map(r => r.subty), ["1", "3"]);
});

console.log("locking / authorization");
test("employee locked by another user cannot be locked", () => {
    const r = PA.lock("10000004");
    assert.strictEqual(r.ok, false);
    assert.deepStrictEqual(r.errors[0], { code: "LOCKED", params: ["HRADMIN2"] });
});
test("lock and unlock", () => {
    assert.strictEqual(PA.lock("10000001").ok, true);
    assert.strictEqual(PA.getLock("10000001"), PA.USER);
    PA.unlock("10000001");
    assert.strictEqual(PA.getLock("10000001"), "");
    PA.unlock("10000004"); // not ours -> must stay locked
    assert.strictEqual(PA.getLock("10000004"), "HRADMIN2");
});
test("changes need the lock", () => {
    const r = PA.create({ pernr: "10000001", infty: "0002", begda: "2025-01-01", nachn: "Hong", vorna: "G", gbdat: "1988-04-12", gesch: "1" });
    assert.deepStrictEqual(codes(r), ["NOT_LOCKED"]);
});
test("infotype 0000 is display-only", () => {
    PA.lock("10000001");
    const r = PA.create({ pernr: "10000001", infty: "0000", begda: "2026-11-01", massn: "02", stat2: "3" });
    assert.deepStrictEqual(codes(r), ["NO_AUTH_MAINTAIN"]);
    assert.strictEqual(PA.canMaintain("0000"), false);
    assert.strictEqual(PA.canMaintain("0002"), true);
});

function p2(extra) {
    return Object.assign({ pernr: "10000001", infty: "0002", anred: "1", nachn: "Hong", vorna: "Gildong", gbdat: "1988-04-12", gesch: "1", natio: "KR", sprsl: "KO", famst: "1", anzkd: 2 }, extra);
}

console.log("create - time constraint 1");
test("new record delimits the valid one and runs to 9999-12-31", () => {
    PA.lock("10000001");
    const r = PA.create(p2({ begda: "2024-01-01", anzkd: 2 }));
    assert.strictEqual(r.ok, true, JSON.stringify(r));
    assert.deepStrictEqual(mcodes(r), ["CREATED", "DELIMITED_PREV"]);
    const all = PA.getRecords("10000001", "0002", { period: "all" });
    assert.strictEqual(all.length, 3);
    assert.strictEqual(all[0].begda, "2024-01-01");
    assert.strictEqual(all[0].endda, FOREVER);
    assert.strictEqual(all[1].endda, "2023-12-31");
    checkConsistency("10000001");
});
test("earlier end date splits the old record (rest is kept)", () => {
    PA.lock("10000001");
    const r = PA.create(p2({ begda: "2024-01-01", endda: "2024-06-30", anzkd: 5 }));
    assert.strictEqual(r.ok, true);
    assert.deepStrictEqual(mcodes(r), ["CREATED", "SPLIT_TAIL", "DELIMITED_PREV"]);
    const all = PA.getRecords("10000001", "0002", { period: "all" }).reverse();
    assert.deepStrictEqual(all.map(x => [x.begda, x.endda, x.anzkd]), [
        ["2015-03-01", "2021-05-31", 0],
        ["2021-06-01", "2023-12-31", 1],
        ["2024-01-01", "2024-06-30", 5],
        ["2024-07-01", FOREVER, 1]
    ]);
    checkConsistency("10000001");
});
test("end date beyond the covering record is adjusted", () => {
    PA.lock("10000001");
    const r = PA.create(p2({ begda: "2017-01-01", endda: "2025-12-31" }));
    assert.strictEqual(r.ok, true);
    assert(mcodes(r).includes("END_ADJUSTED"));
    checkConsistency("10000001");
});
test("same start date -> error, earlier than first record -> error", () => {
    PA.lock("10000001");
    assert.deepStrictEqual(codes(PA.create(p2({ begda: "2021-06-01" }))), ["SAME_START"]);
    assert.deepStrictEqual(codes(PA.create(p2({ begda: "2015-02-28" }))), ["BEFORE_FIRST"]);
});
test("field validation", () => {
    PA.lock("10000001");
    const r = PA.create(p2({ begda: "2025-01-01", nachn: "", gesch: "9", anzkd: "x", gbdat: "1988-13-45" }));
    assert.strictEqual(r.ok, false);
    assert.deepStrictEqual(codes(r).sort(), ["INVALID_DATE", "INVALID_NUMBER", "INVALID_VALUE", "REQUIRED"]);
});
test("date validation", () => {
    PA.lock("10000001");
    assert.deepStrictEqual(codes(PA.create(p2({ begda: "2025-02-30" }))), ["INVALID_DATE"]);
    assert.deepStrictEqual(codes(PA.create(p2({ begda: "2025-05-01", endda: "2025-04-01" }))), ["BEGDA_AFTER_ENDDA"]);
    assert.strictEqual(PA.getRecords("10000001", "0002", { period: "all" }).length, 2); // nothing changed
});
test("failed create does not modify existing records", () => {
    PA.lock("10000001");
    const before = JSON.stringify(PA.getRecords("10000001", "0002", { period: "all" }));
    PA.create(p2({ begda: "2021-06-01" }));
    assert.strictEqual(JSON.stringify(PA.getRecords("10000001", "0002", { period: "all" })), before);
});

console.log("create - time constraint 2 (addresses)");
function addr(extra) {
    return Object.assign({ pernr: "10000001", infty: "0006", subty: "1", stras: "1 Test-ro", ort01: "Seoul", land1: "KR" }, extra);
}
test("new address of the same subtype delimits the valid one", () => {
    PA.lock("10000001");
    const r = PA.create(addr({ begda: "2025-01-01" }));
    assert.strictEqual(r.ok, true, JSON.stringify(r));
    assert.deepStrictEqual(mcodes(r), ["CREATED", "DELIMITED_PREV"]);
    const s1 = PA.getRecords("10000001", "0006", { period: "all" }).filter(x => x.subty === "1");
    assert.deepStrictEqual(s1.map(x => [x.begda, x.endda]), [["2025-01-01", FOREVER], ["2021-01-01", "2024-12-31"], ["2015-03-01", "2020-12-31"]]);
    checkConsistency("10000001");
});
test("gaps are allowed, other subtypes are independent", () => {
    PA.lock("10000001");
    assert.strictEqual(PA.create(addr({ subty: "3", begda: "2024-01-01" })).ok, true);
    assert.strictEqual(PA.create(addr({ subty: "2", begda: "2023-03-01", endda: "2023-06-30" })).ok, true);
    checkConsistency("10000001");
});
test("overlap with a later record is rejected", () => {
    PA.lock("10000001");
    const r = PA.create(addr({ begda: "2020-06-01", endda: FOREVER }));
    assert.deepStrictEqual(codes(r), ["OVERLAP"]);
});
test("subtype is required for 0006", () => {
    PA.lock("10000001");
    assert.deepStrictEqual(codes(PA.create(addr({ subty: "", begda: "2025-01-01" }))), ["REQUIRED"]);
});

console.log("change");
test("change keeps dates and updates fields", () => {
    PA.lock("10000001");
    const cur = PA.getRecords("10000001", "0002", { period: "current" })[0];
    const r = PA.change(cur.id, p2({ anzkd: 3, famst: "3", begda: "1900-01-01", endda: "1901-01-01" }));
    assert.strictEqual(r.ok, true, JSON.stringify(r));
    const now = PA.getRecord(cur.id);
    assert.strictEqual(now.anzkd, 3);
    assert.strictEqual(now.famst, "3");
    assert.strictEqual(now.begda, cur.begda);
    assert.strictEqual(now.endda, cur.endda);
});
test("change validates required fields", () => {
    PA.lock("10000001");
    const cur = PA.getRecords("10000001", "0002", { period: "current" })[0];
    assert.deepStrictEqual(codes(PA.change(cur.id, p2({ vorna: "" }))), ["REQUIRED"]);
});
test("change of an unknown record", () => {
    PA.lock("10000001");
    assert.deepStrictEqual(codes(PA.change("nope", {})), ["RECORD_NOT_FOUND"]);
});

console.log("delimit");
test("delimit works for time constraint 2 only", () => {
    PA.lock("10000001");
    const cur = PA.getRecords("10000001", "0006", { period: "current" })[0]; // 2021-01-01..9999
    assert.strictEqual(PA.delimit(cur.id, "2026-12-31").ok, true);
    assert.strictEqual(PA.getRecord(cur.id).endda, "2026-12-31");
    const t1 = PA.getRecords("10000001", "0002", { period: "current" })[0];
    assert.deepStrictEqual(codes(PA.delimit(t1.id, "2026-12-31")), ["TC1_NO_DELIMIT"]);
});
test("delimit date must be inside the record", () => {
    PA.lock("10000001");
    const cur = PA.getRecords("10000001", "0006", { period: "current" })[0];
    assert.deepStrictEqual(codes(PA.delimit(cur.id, "2020-01-01")), ["DELIMIT_INVALID"]);
    assert.deepStrictEqual(codes(PA.delimit(cur.id, FOREVER)), ["DELIMIT_INVALID"]);
    assert.deepStrictEqual(codes(PA.delimit(cur.id, "nonsense")), ["INVALID_DATE"]);
});

console.log("delete");
test("TC1: deleting a middle/last record extends the previous one", () => {
    PA.lock("10000001");
    const all = PA.getRecords("10000001", "0001", { period: "all" }); // newest first
    const r = PA.remove(all[0].id); // 2023-07-01..9999
    assert.strictEqual(r.ok, true);
    assert.deepStrictEqual(mcodes(r), ["DELETED", "STRETCHED_PREV"]);
    checkConsistency("10000001");
    assert.strictEqual(PA.getRecords("10000001", "0001", { period: "all" }).length, 2);
});
test("TC1: deleting the first record moves the next start back", () => {
    PA.lock("10000001");
    const all = PA.getRecords("10000001", "0001", { period: "all" });
    const first = all[all.length - 1];
    const r = PA.remove(first.id);
    assert.deepStrictEqual(mcodes(r), ["DELETED", "MOVED_NEXT"]);
    const left = PA.getRecords("10000001", "0001", { period: "all" });
    assert.strictEqual(left[left.length - 1].begda, "2015-03-01");
    checkConsistency("10000001");
});
test("TC1: the last remaining record cannot be deleted", () => {
    PA.lock("10000002");
    const only = PA.getRecords("10000002", "0002", { period: "all" });
    assert.strictEqual(only.length, 1);
    assert.deepStrictEqual(codes(PA.remove(only[0].id)), ["LAST_RECORD"]);
});
test("TC2: delete simply removes the record", () => {
    PA.lock("10000001");
    const t = PA.getRecords("10000001", "0006", { period: "all" }).filter(x => x.subty === "2")[0];
    const r = PA.remove(t.id);
    assert.deepStrictEqual(mcodes(r), ["DELETED"]);
    assert.strictEqual(PA.getRecord(t.id), null);
});

console.log("copy");
test("copy defaults start after the existing record and run to 9999-12-31", () => {
    const cur = PA.getRecords("10000001", "0006", { period: "current" })[0];
    const d = PA.copyDefaults(cur.id);
    assert.strictEqual(d.begda, "2026-10-01");
    assert.strictEqual(d.endda, FOREVER);
    assert.strictEqual(d.id, undefined);
    assert.strictEqual(d.stras, cur.stras);
});

console.log("personnel actions (PA40)");
function hireInput(over) {
    const d = PA.actionDefaults("01", null, "2026-11-01");
    d.steps["0001"].orgeh = "50000020"; d.steps["0001"].plans = "60000201";
    d.steps["0002"].nachn = "Lee"; d.steps["0002"].vorna = "Minjun";
    d.steps["0002"].gbdat = "1999-02-02"; d.steps["0002"].gesch = "1";
    d.steps["0006"].stras = "1 Sample-ro"; d.steps["0006"].ort01 = "Seoul";
    return Object.assign({ massn: "01", massg: "01", begda: "2026-11-01", steps: d.steps }, over || {});
}
test("hiring creates a new employee with all infotypes", () => {
    const r = PA.executeAction(hireInput());
    assert.ok(r.ok, JSON.stringify(r));
    assert.strictEqual(r.pernr, "10000007");
    const e = PA.getEmployee(r.pernr, "2026-11-01");
    assert.strictEqual(e.fullName, "Lee Minjun");
    assert.strictEqual(e.status, "3");
    ["0000", "0001", "0002", "0006"].forEach(i =>
        assert.strictEqual(PA.getRecords(r.pernr, i, { period: "all" }).length, 1, i));
    assert.strictEqual(PA.getLock(r.pernr), "");
    assert.ok(mcodes(r).includes("ACTION_DONE"));
    checkConsistency(r.pernr);
});
test("hiring is atomic: invalid step saves nothing", () => {
    const inp = hireInput();
    inp.steps["0006"].stras = "";
    const before = PA.searchEmployees({}, "2026-11-01").length;
    const r = PA.executeAction(inp);
    assert.ok(!r.ok);
    assert.strictEqual(r.errors[0].infty, "0006");
    assert.deepStrictEqual(codes(r), ["REQUIRED"]);
    assert.strictEqual(PA.searchEmployees({}, "2026-11-01").length, before);
    assert.strictEqual(PA.getEmployee("10000007", "2026-11-01"), null);
    assert.strictEqual(PA.getRecords("10000007", "0000", { period: "all" }).length, 0);
    // numbering is not burned by the failed attempt
    assert.strictEqual(PA.executeAction(hireInput()).pernr, "10000007");
});
test("org reassignment writes 0000 and a new 0001 record", () => {
    const d = PA.actionDefaults("02", "10000002", "2026-11-01");
    assert.strictEqual(d.steps["0001"].orgeh, "50000020");
    d.steps["0001"].orgeh = "50000030"; d.steps["0001"].plans = "60000301";
    const r = PA.executeAction({ massn: "02", massg: "02", pernr: "10000002", begda: "2026-11-01", steps: d.steps });
    assert.ok(r.ok, JSON.stringify(r));
    const p0 = PA.getRecords("10000002", "0000", { period: "all" });
    assert.strictEqual(p0.length, 2);
    assert.strictEqual(p0[0].massn, "02");
    assert.strictEqual(p0[0].stat2, "3");
    assert.strictEqual(PA.getEmployee("10000002", "2026-11-01").orgeh, "50000030");
    assert.strictEqual(PA.getEmployee("10000002", "2026-10-31").orgeh, "50000020");
    assert.strictEqual(PA.getLock("10000002"), "");
    checkConsistency("10000002");
});
test("leaving sets the status to withdrawn from the action date", () => {
    const r = PA.executeAction({ massn: "10", massg: "10", pernr: "10000002", begda: "2026-12-31", steps: {} });
    assert.ok(r.ok, JSON.stringify(r));
    assert.strictEqual(PA.getEmployee("10000002", "2026-12-30").status, "3");
    assert.strictEqual(PA.getEmployee("10000002", "2026-12-31").status, "0");
    checkConsistency("10000002");
});
test("actions on a leaver are rejected", () => {
    const r = PA.executeAction({ massn: "10", massg: "10", pernr: "10000005", begda: "2026-10-01", steps: {} });
    assert.deepStrictEqual(codes(r), ["NOT_ACTIVE"]);
});
test("locked employee cannot be processed and stays unchanged", () => {
    const r = PA.executeAction({ massn: "10", massg: "10", pernr: "10000004", begda: "2026-12-31", steps: {} });
    assert.deepStrictEqual(codes(r), ["LOCKED"]);
    assert.strictEqual(PA.getLock("10000004"), "HRADMIN2");
    assert.strictEqual(PA.getRecords("10000004", "0000", { period: "all" }).length, 1);
});
test("same-day action is rejected as a whole", () => {
    const d = PA.actionDefaults("02", "10000002", "2026-11-01");
    assert.ok(PA.executeAction({ massn: "02", pernr: "10000002", begda: "2026-11-01", steps: d.steps }).ok);
    const r = PA.executeAction({ massn: "10", massg: "10", pernr: "10000002", begda: "2026-11-01", steps: {} });
    assert.deepStrictEqual(codes(r), ["SAME_START"]);
    assert.strictEqual(PA.getEmployee("10000002", "2026-11-01").status, "3");
});
test("unknown action, bad date, unknown employee", () => {
    assert.deepStrictEqual(codes(PA.executeAction({ massn: "99", begda: "2026-11-01" })), ["UNKNOWN_ACTION"]);
    assert.deepStrictEqual(codes(PA.executeAction({ massn: "10", pernr: "10000002", begda: "x" })), ["INVALID_DATE"]);
    assert.deepStrictEqual(codes(PA.executeAction({ massn: "10", pernr: "99999999", begda: "2026-11-01" })), ["EMPLOYEE_NOT_FOUND"]);
});
test("a lock held by the user before the action is kept", () => {
    PA.lock("10000002");
    const d = PA.actionDefaults("02", "10000002", "2026-11-01");
    assert.ok(PA.executeAction({ massn: "02", pernr: "10000002", begda: "2026-11-01", steps: d.steps }).ok);
    assert.strictEqual(PA.getLock("10000002"), PA.USER);
});

console.log("reset");
test("reset restores the sample data", () => {
    PA.lock("10000001");
    PA.create(p2({ begda: "2024-01-01" }));
    PA.reset();
    assert.strictEqual(PA.getRecords("10000001", "0002", { period: "all" }).length, 2);
    assert.strictEqual(PA.getLock("10000001"), "");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
