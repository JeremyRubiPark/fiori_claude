/**
 * OrgLogic - service layer of the org chart prototype.
 *
 * The controllers only use the functions returned at the bottom. To connect the app to
 * SuccessFactors Employee Central, re-implement them on top of the OData API (see
 * docs/ec-integration.md); the UI does not have to change.
 *
 * All dates are ISO strings "YYYY-MM-DD". No UI dependency (runs in Node for tests).
 */
sap.ui.define(["./OrgData"], function (OrgData) {
    "use strict";

    var FOREVER = OrgData.FOREVER;
    var state;
    var fixedToday = null;

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
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
        var d = new Date(+p[0], +p[1] - 1, +p[2]);
        return d.getFullYear() === +p[0] && d.getMonth() === +p[1] - 1 && d.getDate() === +p[2];
    }

    function validAt(x, date) {
        return x.begda <= date && date <= x.endda;
    }

    function reset() {
        state = OrgData.seed();
    }

    function setToday(iso) {
        fixedToday = iso;
    }

    function dateOf(keyDate) {
        return isIso(keyDate) ? keyDate : todayIso();
    }

    function unitsAt(date) {
        return state.units.filter(function (u) {
            return validAt(u, date);
        });
    }

    function employeesAt(date) {
        return state.employees.filter(function (e) {
            return validAt(e, date);
        });
    }

    function findEmployee(pernr) {
        return state.employees.filter(function (e) {
            return e.pernr === pernr;
        })[0] || null;
    }

    /** ids of the unit and all valid sub-units (recursive) */
    function subtreeIds(id, date) {
        var valid = unitsAt(date);
        var out = [id];
        var queue = [id];
        while (queue.length) {
            var cur = queue.shift();
            valid.forEach(function (u) {
                if (u.parent === cur && out.indexOf(u.id) < 0) {
                    out.push(u.id);
                    queue.push(u.id);
                }
            });
        }
        return out;
    }

    function managerName(unit, date) {
        var e = findEmployee(unit.manager);
        return e && validAt(e, date) ? e.name : "";
    }

    /**
     * Organization tree valid at the key date.
     * query (optional): keeps units whose name or id contains the text, plus their
     * ancestors, so the hit stays reachable. Each node has:
     *   { id, name, manager, headcount (direct), total (incl. sub-units), match, nodes: [] }
     */
    function getTree(keyDate, query) {
        var date = dateOf(keyDate);
        var q = (query || "").trim().toLowerCase();
        var valid = unitsAt(date);
        var members = employeesAt(date);

        function build(u) {
            var node = {
                id: u.id,
                name: u.name,
                manager: managerName(u, date),
                headcount: members.filter(function (e) {
                    return e.org === u.id;
                }).length,
                match: !!q && (u.name.toLowerCase().indexOf(q) >= 0 || u.id.indexOf(q) >= 0),
                nodes: []
            };
            var ids = subtreeIds(u.id, date);
            node.total = members.filter(function (e) {
                return ids.indexOf(e.org) >= 0;
            }).length;
            valid.filter(function (c) {
                return c.parent === u.id;
            }).sort(function (a, b) {
                return a.id < b.id ? -1 : 1;
            }).forEach(function (c) {
                node.nodes.push(build(c));
            });
            return node;
        }

        function prune(node) {
            node.nodes = node.nodes.map(prune).filter(Boolean);
            return node.match || node.nodes.length ? node : null;
        }

        var ids = valid.map(function (u) {
            return u.id;
        });
        var roots = valid.filter(function (u) {
            return !u.parent || ids.indexOf(u.parent) < 0;
        }).sort(function (a, b) {
            return a.id < b.id ? -1 : 1;
        }).map(build);
        return q ? roots.map(prune).filter(Boolean) : roots;
    }

    /** details of one unit at the key date, or null if it does not exist at that date */
    function getUnit(id, keyDate) {
        var date = dateOf(keyDate);
        var valid = unitsAt(date);
        var u = valid.filter(function (x) {
            return x.id === id;
        })[0];
        if (!u) {
            return null;
        }
        var members = employeesAt(date);
        var ids = subtreeIds(id, date);
        var path = [];
        var cur = u;
        while (cur) {
            path.unshift(cur.name);
            cur = valid.filter(function (x) {
                return x.id === cur.parent;
            })[0];
        }
        return {
            id: u.id,
            name: u.name,
            parent: u.parent,
            path: path,
            managerPernr: u.manager,
            managerName: managerName(u, date),
            begda: u.begda,
            endda: u.endda,
            childCount: valid.filter(function (x) {
                return x.parent === id;
            }).length,
            headcount: members.filter(function (e) {
                return e.org === id;
            }).length,
            total: members.filter(function (e) {
                return ids.indexOf(e.org) >= 0;
            }).length
        };
    }

    /** employees of a unit (optionally incl. sub-units) active at the key date; manager first */
    function getMembers(id, keyDate, includeSub) {
        var date = dateOf(keyDate);
        var valid = unitsAt(date);
        var unit = valid.filter(function (x) {
            return x.id === id;
        })[0];
        if (!unit) {
            return [];
        }
        var ids = includeSub ? subtreeIds(id, date) : [id];
        var names = {};
        valid.forEach(function (u) {
            names[u.id] = u.name;
        });
        return employeesAt(date).filter(function (e) {
            return ids.indexOf(e.org) >= 0;
        }).map(function (e) {
            var own = valid.filter(function (u) {
                return u.id === e.org;
            })[0];
            return {
                pernr: e.pernr,
                name: e.name,
                title: e.title,
                orgId: e.org,
                orgName: names[e.org] || e.org,
                isManager: !!own && own.manager === e.pernr,
                entryDate: e.begda
            };
        }).sort(function (a, b) {
            if (a.isManager !== b.isManager) {
                return a.isManager ? -1 : 1;
            }
            if (a.orgId !== b.orgId) {
                return a.orgId < b.orgId ? -1 : 1;
            }
            return a.pernr < b.pernr ? -1 : 1;
        });
    }

    reset();

    return {
        FOREVER: FOREVER,
        reset: reset,
        setToday: setToday,
        today: todayIso,
        isIso: isIso,
        getTree: getTree,
        getUnit: getUnit,
        getMembers: getMembers
    };
});
