/**
 * Sample data for the PA20/PA30 prototype (no real people, all values invented).
 *
 * The dates form realistic, date-effective histories that respect the time
 * constraints defined in infotypes.js. Personnel number 10000004 is locked by
 * another user to demonstrate the enqueue (lock) behaviour of PA30. Personnel
 * number 10000006 is a future hire.
 */
sap.ui.define(["./infotypes"], function (IT) {
    "use strict";

    var F = IT.FOREVER;

    function seed() {
        var records = [];

        function add(pernr, infty, subty, begda, endda, values) {
            var rec = { pernr: pernr, infty: infty, subty: subty || "", begda: begda, endda: endda };
            Object.keys(values).forEach(function (k) {
                rec[k] = values[k];
            });
            rec.aedtm = "2026-01-15";
            rec.uname = "HRADMIN";
            records.push(rec);
        }

        // ---- 10000001 Hong Gildong - IT, moved to HR in 2023 -------------------------
        add("10000001", "0000", "", "2015-03-01", "2019-12-31", { massn: "01", massg: "01", stat2: "3" });
        add("10000001", "0000", "", "2020-01-01", F, { massn: "02", massg: "02", stat2: "3" });
        add("10000001", "0001", "", "2015-03-01", "2019-12-31", { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000020", plans: "60000201", stell: "70000003", kostl: "1000200", abkrs: "K1" });
        add("10000001", "0001", "", "2020-01-01", "2023-06-30", { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000020", plans: "60000202", stell: "70000002", kostl: "1000200", abkrs: "K1" });
        add("10000001", "0001", "", "2023-07-01", F, { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000010", plans: "60000101", stell: "70000001", kostl: "1000100", abkrs: "K1" });
        add("10000001", "0002", "", "2015-03-01", "2021-05-31", { anred: "1", nachn: "Hong", vorna: "Gildong", gbdat: "1988-04-12", gesch: "1", natio: "KR", sprsl: "KO", famst: "0", anzkd: 0 });
        add("10000001", "0002", "", "2021-06-01", F, { anred: "1", nachn: "Hong", vorna: "Gildong", gbdat: "1988-04-12", gesch: "1", natio: "KR", sprsl: "KO", famst: "1", anzkd: 1 });
        add("10000001", "0006", "1", "2015-03-01", "2020-12-31", { stras: "12 Teheran-ro", ort01: "Seoul", pstlz: "06141", land1: "KR", telnr: "02-555-0101" });
        add("10000001", "0006", "1", "2021-01-01", F, { stras: "88 Pangyo-ro", ort01: "Seongnam", pstlz: "13529", land1: "KR", telnr: "031-555-0102" });
        add("10000001", "0006", "2", "2022-01-01", "2022-12-31", { stras: "5 Haeundae-ro", ort01: "Busan", pstlz: "48094", land1: "KR", telnr: "051-555-0103" });

        // ---- 10000002 Kim Chulsoo - IT engineer -------------------------------------
        add("10000002", "0000", "", "2018-09-03", F, { massn: "01", massg: "01", stat2: "3" });
        add("10000002", "0001", "", "2018-09-03", "2022-02-28", { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000020", plans: "60000201", stell: "70000003", kostl: "1000200", abkrs: "K1" });
        add("10000002", "0001", "", "2022-03-01", F, { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000020", plans: "60000202", stell: "70000002", kostl: "1000200", abkrs: "K1" });
        add("10000002", "0002", "", "2018-09-03", F, { anred: "1", nachn: "Kim", vorna: "Chulsoo", gbdat: "1991-11-03", gesch: "1", natio: "KR", sprsl: "KO", famst: "0", anzkd: 0 });
        add("10000002", "0006", "1", "2018-09-03", F, { stras: "27 Gwanak-ro", ort01: "Seoul", pstlz: "08788", land1: "KR", telnr: "02-555-0201" });

        // ---- 10000003 Lee Younghee - Finance ----------------------------------------
        add("10000003", "0000", "", "2012-05-07", F, { massn: "01", massg: "01", stat2: "3" });
        add("10000003", "0001", "", "2012-05-07", F, { bukrs: "1000", werks: "1100", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000030", plans: "60000301", stell: "70000002", kostl: "1000300", abkrs: "K1" });
        add("10000003", "0002", "", "2012-05-07", "2019-03-31", { anred: "2", nachn: "Lee", vorna: "Younghee", gbdat: "1985-07-21", gesch: "2", natio: "KR", sprsl: "KO", famst: "1", anzkd: 0 });
        add("10000003", "0002", "", "2019-04-01", F, { anred: "2", nachn: "Lee", vorna: "Younghee", gbdat: "1985-07-21", gesch: "2", natio: "KR", sprsl: "KO", famst: "1", anzkd: 2 });
        add("10000003", "0006", "1", "2012-05-07", F, { stras: "301 Jungang-daero", ort01: "Busan", pstlz: "47545", land1: "KR", telnr: "051-555-0301" });
        add("10000003", "0006", "3", "2016-01-01", F, { stras: "40 Suyeong-ro", ort01: "Busan", pstlz: "48200", land1: "KR", telnr: "010-5555-0302" });

        // ---- 10000004 Park Minsu - locked by another user ---------------------------
        add("10000004", "0000", "", "2020-02-17", F, { massn: "01", massg: "01", stat2: "3" });
        add("10000004", "0001", "", "2020-02-17", F, { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K2", orgeh: "50000020", plans: "60000201", stell: "70000003", kostl: "1000200", abkrs: "K1" });
        add("10000004", "0002", "", "2020-02-17", F, { anred: "1", nachn: "Park", vorna: "Minsu", gbdat: "1994-01-30", gesch: "1", natio: "KR", sprsl: "KO", famst: "0", anzkd: 0 });
        add("10000004", "0006", "1", "2020-02-17", F, { stras: "9 Sejong-daero", ort01: "Seoul", pstlz: "04513", land1: "KR", telnr: "02-555-0401" });

        // ---- 10000005 Choi Jiyoung - left the company -------------------------------
        add("10000005", "0000", "", "2018-04-02", "2024-12-31", { massn: "01", massg: "01", stat2: "3" });
        add("10000005", "0000", "", "2025-01-01", F, { massn: "10", massg: "10", stat2: "0" });
        add("10000005", "0001", "", "2018-04-02", F, { bukrs: "1000", werks: "1200", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000040", plans: "60000401", stell: "70000001", kostl: "1000400", abkrs: "K1" });
        add("10000005", "0002", "", "2018-04-02", F, { anred: "2", nachn: "Choi", vorna: "Jiyoung", gbdat: "1989-09-09", gesch: "2", natio: "KR", sprsl: "KO", famst: "3", anzkd: 1 });
        add("10000005", "0006", "1", "2018-04-02", "2024-12-31", { stras: "15 Dongseong-ro", ort01: "Daegu", pstlz: "41941", land1: "KR", telnr: "053-555-0501" });

        // ---- 10000006 Jung Sunghyun - future hire -----------------------------------
        add("10000006", "0000", "", "2027-01-04", F, { massn: "01", massg: "01", stat2: "3" });
        add("10000006", "0001", "", "2027-01-04", F, { bukrs: "1000", werks: "1000", btrtl: "0001", persg: "1", persk: "K1", orgeh: "50000040", plans: "60000402", stell: "70000002", kostl: "1000400", abkrs: "K1" });
        add("10000006", "0002", "", "2027-01-04", F, { anred: "1", nachn: "Jung", vorna: "Sunghyun", gbdat: "1996-06-18", gesch: "1", natio: "KR", sprsl: "KO", famst: "0", anzkd: 0 });
        add("10000006", "0006", "1", "2027-01-04", F, { stras: "71 Hangang-daero", ort01: "Seoul", pstlz: "04386", land1: "KR", telnr: "010-5555-0601" });

        records.forEach(function (r, i) {
            r.id = "R" + (i + 1);
        });

        return {
            employees: ["10000001", "10000002", "10000003", "10000004", "10000005", "10000006"],
            records: records,
            locks: { "10000004": "HRADMIN2" }
        };
    }

    return { seed: seed };
});
