/**
 * Sample organization for the EC org chart prototype (all names are invented).
 *
 * units:     { id, name, parent, manager (pernr), begda, endda }
 *            - 50000099 "Overseas Sales Team" exists only from 2027-01-01 (future)
 *            - 50000041 "Legacy Sales Team" was closed on 2025-12-31 (past)
 * employees: { pernr, name, title, org, begda (entry), endda (exit) }
 *            - 10000017 left on 2026-06-30, 10000021 joins on 2026-11-02
 */
sap.ui.define([], function () {
    "use strict";

    var F = "9999-12-31";

    function seed() {
        var units = [
            { id: "50000000", name: "Sample Corp Korea", parent: "", manager: "10000001", begda: "2010-01-01", endda: F },
            { id: "50000010", name: "HR Department", parent: "50000000", manager: "10000002", begda: "2010-01-01", endda: F },
            { id: "50000011", name: "Recruiting Team", parent: "50000010", manager: "10000004", begda: "2012-04-01", endda: F },
            { id: "50000012", name: "Compensation Team", parent: "50000010", manager: "10000005", begda: "2012-04-01", endda: F },
            { id: "50000020", name: "IT Department", parent: "50000000", manager: "10000006", begda: "2010-01-01", endda: F },
            { id: "50000021", name: "Development Team", parent: "50000020", manager: "10000008", begda: "2011-06-01", endda: F },
            { id: "50000022", name: "Infrastructure Team", parent: "50000020", manager: "10000011", begda: "2011-06-01", endda: F },
            { id: "50000030", name: "Finance Department", parent: "50000000", manager: "10000013", begda: "2010-01-01", endda: F },
            { id: "50000031", name: "Accounting Team", parent: "50000030", manager: "10000014", begda: "2012-01-01", endda: F },
            { id: "50000040", name: "Sales Department", parent: "50000000", manager: "10000016", begda: "2010-01-01", endda: F },
            { id: "50000041", name: "Legacy Sales Team", parent: "50000040", manager: "10000017", begda: "2013-01-01", endda: "2025-12-31" },
            { id: "50000042", name: "Domestic Sales Team", parent: "50000040", manager: "10000018", begda: "2013-01-01", endda: F },
            { id: "50000099", name: "Overseas Sales Team", parent: "50000040", manager: "10000021", begda: "2027-01-01", endda: F }
        ];

        var employees = [
            { pernr: "10000001", name: "Han Seojun", title: "CEO", org: "50000000", begda: "2010-01-01", endda: F },
            { pernr: "10000002", name: "Hong Gildong", title: "HR Manager", org: "50000010", begda: "2015-03-01", endda: F },
            { pernr: "10000003", name: "Yoon Haneul", title: "HR Specialist", org: "50000010", begda: "2019-05-02", endda: F },
            { pernr: "10000004", name: "Seo Jiwoo", title: "Recruiting Lead", org: "50000011", begda: "2016-02-01", endda: F },
            { pernr: "10000005", name: "Jang Minseo", title: "Compensation Lead", org: "50000012", begda: "2017-08-01", endda: F },
            { pernr: "10000006", name: "Kim Chulsoo", title: "IT Director", org: "50000020", begda: "2012-09-03", endda: F },
            { pernr: "10000007", name: "Lim Dahee", title: "IT Planner", org: "50000020", begda: "2020-01-06", endda: F },
            { pernr: "10000008", name: "Park Jihun", title: "Development Lead", org: "50000021", begda: "2014-03-03", endda: F },
            { pernr: "10000009", name: "Choi Yerin", title: "Software Engineer", org: "50000021", begda: "2021-03-02", endda: F },
            { pernr: "10000010", name: "Kang Taeyang", title: "Software Engineer", org: "50000021", begda: "2022-07-01", endda: F },
            { pernr: "10000011", name: "Shin Hyunwoo", title: "Infrastructure Lead", org: "50000022", begda: "2015-10-01", endda: F },
            { pernr: "10000012", name: "Bae Sooah", title: "System Engineer", org: "50000022", begda: "2023-02-01", endda: F },
            { pernr: "10000013", name: "Oh Sungmin", title: "Finance Director", org: "50000030", begda: "2011-04-01", endda: F },
            { pernr: "10000014", name: "Ryu Nayoung", title: "Accounting Lead", org: "50000031", begda: "2016-06-01", endda: F },
            { pernr: "10000015", name: "Moon Jaehyun", title: "Accountant", org: "50000031", begda: "2020-09-01", endda: F },
            { pernr: "10000016", name: "Song Minjae", title: "Sales Director", org: "50000040", begda: "2013-01-01", endda: F },
            { pernr: "10000017", name: "Yang Eunji", title: "Sales Lead", org: "50000041", begda: "2014-05-01", endda: "2026-06-30" },
            { pernr: "10000018", name: "Jung Sunghyun", title: "Sales Lead", org: "50000042", begda: "2017-01-02", endda: F },
            { pernr: "10000019", name: "Kwon Areum", title: "Account Executive", org: "50000042", begda: "2021-09-01", endda: F },
            { pernr: "10000020", name: "Hwang Doyoon", title: "Account Executive", org: "50000042", begda: "2024-01-02", endda: F },
            { pernr: "10000021", name: "Nam Gaeun", title: "Overseas Sales Lead", org: "50000099", begda: "2026-11-02", endda: F }
        ];

        return { units: units, employees: employees };
    }

    return { FOREVER: F, seed: seed };
});
