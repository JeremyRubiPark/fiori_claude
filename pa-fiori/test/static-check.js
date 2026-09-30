// Static checks (no UI5 runtime needed): JSON/XML validity, JS syntax, i18n key coverage.
const fs = require("fs"), path = require("path"), cp = require("child_process");
const root = path.join(__dirname, "..", "webapp");
let bad = 0;
const fail = (m) => { console.log("FAIL " + m); bad++; };
const walk = (d) => fs.readdirSync(d).flatMap((f) => { const p = path.join(d, f); return fs.statSync(p).isDirectory() ? walk(p) : [p]; });
const files = walk(root);

files.filter((f) => f.endsWith(".json")).forEach((f) => { try { JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { fail(f + " " + e.message); } });
files.filter((f) => f.endsWith(".js")).forEach((f) => { try { cp.execFileSync("node", ["--check", f]); } catch (e) { fail("syntax " + f); } });
files.filter((f) => f.endsWith(".xml")).forEach((f) => {
  try { cp.execFileSync("python3", ["-c", "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])", f], { stdio: "pipe" }); }
  catch (e) { fail("xml not well-formed: " + f + " " + String(e.stderr).trim().split("\n").pop()); }
});

function props(f) {
  const o = {};
  fs.readFileSync(f, "utf8").split(/\r?\n/).forEach((l) => { if (l && l[0] !== "#") { const i = l.indexOf("="); o[l.slice(0, i)] = l.slice(i + 1); } });
  return o;
}
const en = props(path.join(root, "i18n/i18n.properties")), ko = props(path.join(root, "i18n/i18n_ko.properties"));
Object.keys(en).filter((k) => !(k in ko)).forEach((k) => fail("missing in ko: " + k));
Object.keys(ko).filter((k) => !(k in en)).forEach((k) => fail("missing in en: " + k));
Object.keys(en).forEach((k) => {
  const a = (en[k].match(/\{\d\}/g) || []).sort().join(), b = (ko[k].match(/\{\d\}/g) || []).sort().join();
  if (a !== b) fail("placeholder mismatch " + k);
  if (/'/.test(en[k] + ko[k])) fail("apostrophe in " + k);
});

// keys used
const used = new Set();
files.filter((f) => /\.(js|xml|json)$/.test(f)).forEach((f) => {
  const s = fs.readFileSync(f, "utf8");
  let m;
  const r1 = /i18n>(\w+)/g; while ((m = r1.exec(s))) used.add(m[1]);
  const r2 = /\{\{(\w+)\}\}/g; while ((m = r2.exec(s))) used.add(m[1]);
  const r3 = /(?:getText|btn)\(\s*"(\w+)"/g; while ((m = r3.exec(s))) used.add(m[1]);
});
const IT = {}; global.sap = { ui: { define: (d, fn) => { IT.m = fn({ ...[] }); } } };
const itDef = (() => { let r; global.sap.ui.define = (d, fn) => { r = fn(); }; require(path.join(root, "model/infotypes.js")); return r; })();
itDef.INFOTYPES.forEach((t) => { used.add("it_" + t.id); t.fields.forEach((f) => used.add("f_" + f.name)); });
["subty", "begda", "endda", "aedtm", "uname"].forEach((k) => used.add("f_" + k));
const codes = fs.readFileSync(path.join(root, "model/PALogic.js"), "utf8").matchAll(/err\("(\w+)"/g);
for (const c of codes) used.add("msg_" + c[1]);
["dlg_create", "dlg_copy", "dlg_change"].forEach((k) => used.add(k));
used.delete("it_"); used.delete("f_"); used.delete("msg_"); used.delete("dlg_");
used.forEach((k) => { if (!(k in en)) fail("i18n key used but missing: " + k); });
Object.keys(en).filter((k) => !used.has(k)).forEach((k) => console.log("note: unused key " + k));
console.log(bad ? bad + " problem(s)" : "static checks OK (" + files.length + " files, " + used.size + " keys used)");
process.exit(bad ? 1 : 0);
