/**
 * PALogic - service layer of the PA20/PA30 prototype.
 *
 * This module is the ONLY place that knows how data is stored. The controllers talk
 * to it through the functions returned at the bottom. To connect the app to ECC,
 * re-implement these functions on top of the OData V2 service described in
 * docs/ecc-integration.md - the UI code does not have to change.
 *
 * It has no UI5 dependency except sap.ui.define, so it can be unit tested in Node.
 *
 * Conventions
 *  - all dates are ISO strings "YYYY-MM-DD" (no time zones involved)
 *  - functions never throw for business errors; they return
 *      { ok: false, errors: [ { code, params } ] }
 *    or
 *      { ok: true, messages: [ { code, params } ], record }
 *    The UI translates the codes with the i18n keys msg_<code>.
 */
sap.ui.define(["./infotypes", "./MockData"], function (IT, MockData) {
    "use strict";

    var FOREVER = IT.FOREVER;
    var USER = "DEMO_USER";

    var state;
    var fixedToday = null;

    // ------------------------------------------------------------------ date helpers
    function pad(n) {
        return n < 10 ? "0" + n : String(n);
    }

    function todayIso() {
        if (fixedToday) {
            return fixedToday;
        }
        var d = new Date();
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }

    function isIso(s) {
        if (typeof s !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(s)) {
            return false;
        }
        var p = s.split("-");
        var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2]));
        return d.getUTCFullYear() === +p[0] && d.getUTCMonth() === +p[1] - 1 && d.getUTCDate() === +p[2];
    }

    function addDays(iso, n) {
        var p = iso.split("-");
        var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + n));
        return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate());
    }

    function byBegda(a, b) {
        return a.begda < b.begda ? -1 : (a.begda > b.begda ? 1 : 0);
    }

    function validAt(rec, date) {
        return rec.begda <= date && date <= rec.endda;
    }

    function err(code) {
        return { code: code, params: Array.prototype.slice.call(arguments, 1) };
    }

    function fail() {
        return { ok: false, errors: Array.prototype.slice.call(arguments) };
    }

    // ------------------------------------------------------------------ state
    function reset() {
        var seed = MockData.seed();
        state = {
            employees: seed.employees.slice(),
            records: seed.records,
            locks: JSON.parse(JSON.stringify(seed.locks)),
            nextId: seed.records.length + 1
        };
    }

    function newId() {
        return "R" + (state.nextId++);
    }

    function recsOf(pernr, infty) {
        return state.records.filter(function (r) {
            return r.pernr === pernr && r.infty === infty;
        });
    }

    function findRecord(id) {
        for (var i = 0; i < state.records.length; i++) {
            if (state.records[i].id === id) {
                return state.records[i];
            }
        }
        return null;
    }

    function copyRecord(rec) {
        return JSON.parse(JSON.stringify(rec));
    }

    /** the record valid at 'date'; if there is none the closest earlier one, else the first one */
    function pick(pernr, infty, date) {
        var list = recsOf(pernr, infty).sort(byBegda);
        var hit = null;
        var earlier = null;
        list.forEach(function (r) {
            if (validAt(r, date)) {
                hit = r;
            }
            if (r.begda <= date) {
                earlier = r;
            }
        });
        return hit || earlier || list[0] || null;
    }

    // ------------------------------------------------------------------ reading
    var STATUS_STATE = { "3": "Success", "2": "Warning", "1": "Warning", "0": "Error" };

    function getEmployee(pernr, keyDate) {
        if (state.employees.indexOf(pernr) < 0) {
            return null;
        }
        var date = keyDate || todayIso();
        var p0 = pick(pernr, "0000", date);
        var p1 = pick(pernr, "0001", date);
        var p2 = pick(pernr, "0002", date);
        return {
            pernr: pernr,
            nachn: p2 ? p2.nachn : "",
            vorna: p2 ? p2.vorna : "",
            fullName: p2 ? (p2.nachn + " " + p2.vorna).trim() : pernr,
            orgeh: p1 ? p1.orgeh : "",
            orgehText: p1 ? IT.listText("orgeh", p1.orgeh) : "",
            plans: p1 ? p1.plans : "",
            plansText: p1 ? IT.listText("plans", p1.plans) : "",
            stell: p1 ? p1.stell : "",
            stellText: p1 ? IT.listText("stell", p1.stell) : "",
            status: p0 ? p0.stat2 : "",
            statusText: p0 ? IT.listText("stat2", p0.stat2) : "",
            statusState: p0 ? (STATUS_STATE[p0.stat2] || "None") : "None",
            entryDate: p0 ? recsOf(pernr, "0000").sort(byBegda)[0].begda : "",
            lockedBy: getLock(pernr)
        };
    }

    /**
     * filter: { pernr, name, orgeh }   (all optional; empty = no restriction)
     */
    function searchEmployees(filter, keyDate) {
        var f = filter || {};
        var name = (f.name || "").trim().toLowerCase();
        var pernr = (f.pernr || "").trim();
        return state.employees.map(function (p) {
            return getEmployee(p, keyDate);
        }).filter(function (e) {
            if (pernr && e.pernr.indexOf(pernr) < 0) {
                return false;
            }
            if (f.orgeh && e.orgeh !== f.orgeh) {
                return false;
            }
            if (name) {
                var a = (e.nachn + " " + e.vorna).toLowerCase();
                var b = (e.vorna + " " + e.nachn).toLowerCase();
                if (a.indexOf(name) < 0 && b.indexOf(name) < 0) {
                    return false;
                }
            }
            return true;
        }).sort(function (a, b) {
            return a.pernr < b.pernr ? -1 : 1;
        });
    }

    /**
     * opts: { period: "current" | "all", keyDate }
     * Returns copies sorted by subtype, then newest first. Each copy has _valid
     * (valid at the key date).
     */
    function getRecords(pernr, infty, opts) {
        var o = opts || {};
        var date = o.keyDate || todayIso();
        var list = recsOf(pernr, infty).map(function (r) {
            var c = copyRecord(r);
            c._valid = validAt(r, date);
            return c;
        });
        if (o.period !== "all") {
            list = list.filter(function (r) {
                return r._valid;
            });
        }
        return list.sort(function (a, b) {
            if (a.subty !== b.subty) {
                return a.subty < b.subty ? -1 : 1;
            }
            return a.begda < b.begda ? 1 : (a.begda > b.begda ? -1 : 0);
        });
    }

    function getRecord(id) {
        var r = findRecord(id);
        return r ? copyRecord(r) : null;
    }

    // ------------------------------------------------------------------ locking
    function getLock(pernr) {
        return state.locks[pernr] || "";
    }

    function lock(pernr) {
        var by = getLock(pernr);
        if (by && by !== USER) {
            return fail(err("LOCKED", by));
        }
        state.locks[pernr] = USER;
        return { ok: true };
    }

    function unlock(pernr) {
        if (state.locks[pernr] === USER) {
            delete state.locks[pernr];
        }
    }

    function canMaintain(infty) {
        var def = IT.get(infty);
        return !!def && def.maintain !== false;
    }

    function checkEditable(pernr, infty, viaAction) {
        if (state.employees.indexOf(pernr) < 0) {
            return err("EMPLOYEE_NOT_FOUND", pernr);
        }
        if (!viaAction && !canMaintain(infty)) {
            return err("NO_AUTH_MAINTAIN", infty);
        }
        var by = getLock(pernr);
        if (by && by !== USER) {
            return err("LOCKED", by);
        }
        if (by !== USER) {
            return err("NOT_LOCKED", pernr);
        }
        return null;
    }

    // ------------------------------------------------------------------ validation
    function isBlank(v) {
        return v === undefined || v === null || String(v).trim() === "";
    }

    function validateFields(def, values) {
        var errors = [];
        def.fields.forEach(function (f) {
            var v = values[f.name];
            if (isBlank(v)) {
                if (f.required) {
                    errors.push(err("REQUIRED", f.name));
                }
                return;
            }
            if (f.type === "select") {
                var ok = IT.listItems(f.list).some(function (i) {
                    return i.key === String(v);
                });
                if (!ok) {
                    errors.push(err("INVALID_VALUE", f.name));
                }
            } else if (f.type === "date") {
                if (!isIso(v)) {
                    errors.push(err("INVALID_DATE", f.name));
                }
            } else if (f.type === "int") {
                if (!/^\d+$/.test(String(v))) {
                    errors.push(err("INVALID_NUMBER", f.name));
                }
            } else if (f.type === "text" && f.maxLength && String(v).length > f.maxLength) {
                errors.push(err("TOO_LONG", f.name, f.maxLength));
            }
        });
        return errors;
    }

    function normalize(def, values) {
        var out = {};
        def.fields.forEach(function (f) {
            var v = values[f.name];
            if (isBlank(v)) {
                out[f.name] = f.type === "int" ? 0 : "";
            } else if (f.type === "int") {
                out[f.name] = parseInt(v, 10);
            } else if (f.type === "text") {
                out[f.name] = String(v).trim();
            } else {
                out[f.name] = String(v);
            }
        });
        return out;
    }

    function stamp(rec) {
        rec.aedtm = todayIso();
        rec.uname = USER;
    }

    // ------------------------------------------------------------------ create
    /**
     * rec: { pernr, infty, subty, begda, endda, ...fields }
     *
     * Time constraint 1: the record that is valid on 'begda' is delimited to begda-1
     *   and the new record takes over its remaining validity. If the new end date is
     *   earlier, the rest is kept as a copy of the old record (like PA30 splitting).
     * Time constraint 2: the record of the same subtype valid on 'begda' is delimited;
     *   overlaps with later records are rejected.
     */
    function create(rec) {
        return doCreate(rec, false);
    }

    /** viaAction: called by executeAction, which may also write infotype 0000 */
    function doCreate(rec, viaAction) {
        var def = IT.get(rec.infty);
        if (!def) {
            return fail(err("UNKNOWN_INFOTYPE", rec.infty));
        }
        var pre = checkEditable(rec.pernr, rec.infty, viaAction);
        if (pre) {
            return fail(pre);
        }

        var errors = [];
        var subty = def.subtypeList ? (rec.subty || "") : "";
        if (def.subtypeList) {
            var subtyOk = IT.listItems(def.subtypeList).some(function (i) {
                return i.key === subty;
            });
            if (!subtyOk) {
                errors.push(err("REQUIRED", "subty"));
            }
        }
        var begda = rec.begda;
        var endda = isBlank(rec.endda) ? FOREVER : rec.endda;
        if (!isIso(begda)) {
            errors.push(err("INVALID_DATE", "begda"));
        }
        if (!isIso(endda)) {
            errors.push(err("INVALID_DATE", "endda"));
        }
        if (isIso(begda) && isIso(endda) && begda > endda) {
            errors.push(err("BEGDA_AFTER_ENDDA"));
        }
        errors = errors.concat(validateFields(def, rec));
        if (errors.length) {
            return { ok: false, errors: errors };
        }

        var values = normalize(def, rec);
        var messages = [];
        var created = [];
        var list;
        var covering;

        if (def.tc === "1") {
            list = recsOf(rec.pernr, rec.infty).sort(byBegda);
            if (!list.length) {
                if (endda !== FOREVER) {
                    endda = FOREVER;
                    messages.push(err("END_ADJUSTED", FOREVER));
                }
            } else {
                if (begda < list[0].begda) {
                    return fail(err("BEFORE_FIRST", list[0].begda));
                }
                covering = list.filter(function (r) {
                    return validAt(r, begda);
                })[0];
                if (!covering) {
                    return fail(err("OVERLAP", begda, endda));
                }
                if (covering.begda === begda) {
                    return fail(err("SAME_START", begda));
                }
                var oldEnd = covering.endda;
                if (endda > oldEnd) {
                    endda = oldEnd;
                    messages.push(err("END_ADJUSTED", oldEnd));
                }
                if (endda < oldEnd) {
                    var tail = copyRecord(covering);
                    tail.id = newId();
                    tail.begda = addDays(endda, 1);
                    tail.endda = oldEnd;
                    stamp(tail);
                    created.push(tail);
                    messages.push(err("SPLIT_TAIL", tail.begda, tail.endda));
                }
                covering.endda = addDays(begda, -1);
                stamp(covering);
                messages.push(err("DELIMITED_PREV", covering.endda));
            }
        } else {
            list = recsOf(rec.pernr, rec.infty).filter(function (r) {
                return r.subty === subty;
            }).sort(byBegda);
            covering = list.filter(function (r) {
                return validAt(r, begda);
            })[0];
            if (covering && covering.begda === begda) {
                return fail(err("SAME_START", begda));
            }
            var overlap = list.some(function (r) {
                return r !== covering && r.begda <= endda && r.endda >= begda;
            });
            if (overlap) {
                return fail(err("OVERLAP", begda, endda));
            }
            if (covering) {
                covering.endda = addDays(begda, -1);
                stamp(covering);
                messages.push(err("DELIMITED_PREV", covering.endda));
            }
        }

        var record = { id: newId(), pernr: rec.pernr, infty: rec.infty, subty: subty, begda: begda, endda: endda };
        Object.keys(values).forEach(function (k) {
            record[k] = values[k];
        });
        stamp(record);
        state.records.push(record);
        created.forEach(function (r) {
            state.records.push(r);
        });
        messages.unshift(err("CREATED", begda));
        return { ok: true, record: copyRecord(record), messages: messages };
    }

    // ------------------------------------------------------------------ change
    /** Changes field values only; dates and subtype of a record cannot be changed. */
    function change(id, values) {
        var rec = findRecord(id);
        if (!rec) {
            return fail(err("RECORD_NOT_FOUND"));
        }
        var pre = checkEditable(rec.pernr, rec.infty);
        if (pre) {
            return fail(pre);
        }
        var def = IT.get(rec.infty);
        var errors = validateFields(def, values);
        if (errors.length) {
            return { ok: false, errors: errors };
        }
        var norm = normalize(def, values);
        Object.keys(norm).forEach(function (k) {
            rec[k] = norm[k];
        });
        stamp(rec);
        return { ok: true, record: copyRecord(rec), messages: [err("CHANGED", rec.begda)] };
    }

    // ------------------------------------------------------------------ delimit
    /** Only for time constraint 2: set a new end date for a record. */
    function delimit(id, newEnd) {
        var rec = findRecord(id);
        if (!rec) {
            return fail(err("RECORD_NOT_FOUND"));
        }
        var pre = checkEditable(rec.pernr, rec.infty);
        if (pre) {
            return fail(pre);
        }
        var def = IT.get(rec.infty);
        if (def.tc === "1") {
            return fail(err("TC1_NO_DELIMIT"));
        }
        if (!isIso(newEnd)) {
            return fail(err("INVALID_DATE", "endda"));
        }
        if (newEnd < rec.begda || newEnd >= rec.endda) {
            return fail(err("DELIMIT_INVALID", rec.begda, rec.endda));
        }
        rec.endda = newEnd;
        stamp(rec);
        return { ok: true, record: copyRecord(rec), messages: [err("DELIMITED", newEnd)] };
    }

    // ------------------------------------------------------------------ delete
    /**
     * Time constraint 1: the previous record is extended over the gap; deleting the
     * first record moves the start of the next record back. The last remaining record
     * cannot be deleted.
     */
    function remove(id) {
        var rec = findRecord(id);
        if (!rec) {
            return fail(err("RECORD_NOT_FOUND"));
        }
        var pre = checkEditable(rec.pernr, rec.infty);
        if (pre) {
            return fail(pre);
        }
        var def = IT.get(rec.infty);
        var messages = [];

        if (def.tc === "1") {
            var list = recsOf(rec.pernr, rec.infty).sort(byBegda);
            if (list.length === 1) {
                return fail(err("LAST_RECORD"));
            }
            var idx = list.indexOf(rec);
            if (idx === 0) {
                list[1].begda = rec.begda;
                stamp(list[1]);
                messages.push(err("MOVED_NEXT", rec.begda));
            } else {
                list[idx - 1].endda = rec.endda;
                stamp(list[idx - 1]);
                messages.push(err("STRETCHED_PREV", rec.endda));
            }
        }
        state.records.splice(state.records.indexOf(rec), 1);
        messages.unshift(err("DELETED", rec.begda));
        return { ok: true, messages: messages };
    }

    // ------------------------------------------------------------------ helpers for the UI
    /** default values for a new record that is copied from an existing one */
    function copyDefaults(id) {
        var rec = findRecord(id);
        if (!rec) {
            return null;
        }
        var c = copyRecord(rec);
        var start = todayIso();
        if (start <= rec.begda) {
            start = addDays(rec.endda === FOREVER ? rec.begda : rec.endda, 1);
        }
        c.begda = start;
        c.endda = FOREVER;
        delete c.id;
        return c;
    }

    // ------------------------------------------------------------------ personnel actions (PA40)
    function nextPernr() {
        var max = 10000000;
        state.employees.forEach(function (p) {
            if (+p > max) {
                max = +p;
            }
        });
        return String(max + 1);
    }

    function activeAt(pernr, date) {
        var r = recsOf(pernr, "0000").filter(function (x) {
            return validAt(x, date);
        })[0];
        return !!r && r.stat2 === "3";
    }

    /**
     * Start values for the steps of an action: copies of the records valid on 'begda'
     * for an existing employee, sample defaults for a hiring.
     * Returns { steps: { "0001": {field: value, ...}, ... } } or null for an unknown action.
     */
    function actionDefaults(massn, pernr, begda) {
        var action = IT.getAction(massn);
        if (!action) {
            return null;
        }
        var date = isIso(begda) ? begda : todayIso();
        var steps = {};
        action.steps.forEach(function (infty) {
            var def = IT.get(infty);
            var values = {};
            var cur = action.newEmployee ? null : pick(pernr, infty, date);
            if (cur) {
                def.fields.forEach(function (f) {
                    values[f.name] = cur[f.name];
                });
                if (def.subtypeList) {
                    values.subty = cur.subty;
                }
            } else {
                values = JSON.parse(JSON.stringify((IT.HIRE_DEFAULTS || {})[infty] || {}));
            }
            steps[infty] = values;
        });
        return { steps: steps };
    }

    /**
     * Executes a personnel action atomically.
     * input: { massn, massg, pernr (not for hiring), begda, steps: { infty: {field: value} } }
     * Success: { ok: true, pernr, messages } - nothing is saved when any step fails:
     * then { ok: false, errors: [ { code, params, infty } ] } and the data is unchanged.
     */
    function executeAction(input) {
        var action = IT.getAction(input.massn);
        if (!action) {
            return fail(err("UNKNOWN_ACTION", input.massn));
        }
        if (!isIso(input.begda)) {
            return fail(err("INVALID_DATE", "begda"));
        }
        var begda = input.begda;
        var pernr = input.pernr;
        if (!action.newEmployee) {
            if (state.employees.indexOf(pernr) < 0) {
                return fail(err("EMPLOYEE_NOT_FOUND", pernr));
            }
            if (!activeAt(pernr, begda)) {
                return fail(err("NOT_ACTIVE", pernr));
            }
        }

        var snapshot = JSON.stringify({
            employees: state.employees,
            records: state.records,
            locks: state.locks,
            nextId: state.nextId
        });
        function rollback() {
            var s = JSON.parse(snapshot);
            state.employees = s.employees;
            state.records = s.records;
            state.locks = s.locks;
            state.nextId = s.nextId;
        }
        function abort(errors, infty) {
            rollback();
            return {
                ok: false,
                errors: errors.map(function (e) {
                    return { code: e.code, params: e.params, infty: infty };
                })
            };
        }

        if (action.newEmployee) {
            pernr = nextPernr();
            state.employees.push(pernr);
        }
        var hadLock = getLock(pernr) === USER;
        var lockRes = lock(pernr);
        if (!lockRes.ok) {
            return abort(lockRes.errors, "");
        }

        var stat2 = action.stat2;
        if (!stat2) {
            var cur0 = recsOf(pernr, "0000").filter(function (x) {
                return validAt(x, begda);
            })[0];
            stat2 = cur0 ? cur0.stat2 : "3";
        }
        var messages = [];
        var seq = [{ infty: "0000", values: { massn: input.massn, massg: input.massg || "", stat2: stat2 } }];
        action.steps.forEach(function (infty) {
            seq.push({ infty: infty, values: (input.steps || {})[infty] || {} });
        });

        for (var i = 0; i < seq.length; i++) {
            var rec = { pernr: pernr, infty: seq[i].infty, begda: begda, endda: FOREVER };
            Object.keys(seq[i].values).forEach(function (k) {
                rec[k] = seq[i].values[k];
            });
            var res = doCreate(rec, true);
            if (!res.ok) {
                return abort(res.errors, seq[i].infty);
            }
            messages = messages.concat(res.messages);
        }
        if (!hadLock) {
            delete state.locks[pernr];
        }
        messages.push(err("ACTION_DONE", IT.listText("massn", input.massn), pernr, begda));
        return { ok: true, pernr: pernr, messages: messages };
    }

    function setToday(iso) {
        fixedToday = iso;
    }

    reset();

    return {
        FOREVER: FOREVER,
        USER: USER,
        reset: reset,
        setToday: setToday,
        today: todayIso,
        addDays: addDays,
        isIso: isIso,
        getEmployee: getEmployee,
        searchEmployees: searchEmployees,
        getRecords: getRecords,
        getRecord: getRecord,
        getLock: getLock,
        lock: lock,
        unlock: unlock,
        canMaintain: canMaintain,
        create: create,
        change: change,
        delimit: delimit,
        remove: remove,
        copyDefaults: copyDefaults,
        actionDefaults: actionDefaults,
        executeAction: executeAction
    };
});
