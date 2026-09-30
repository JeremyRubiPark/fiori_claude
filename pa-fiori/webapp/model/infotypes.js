/**
 * Infotype metadata for the PA20/PA30 prototype.
 *
 * Everything the UI and the service layer need to know about an infotype is
 * defined here, so adding another infotype (e.g. 0105 Communication) means adding
 * one entry - no new view code.
 *
 * Code values (action types, org units, ...) are SAMPLE values. Replace them with
 * the customizing of your ECC system (T529A, T530, T500P, T001P, T591A, ...) or
 * read them from the ECC value-help entity sets when the real service is connected.
 *
 * tc (time constraint):
 *   "1" - exactly one record at every date, no gaps, no overlaps, last record ends 9999-12-31
 *   "2" - at most one record per subtype at any date, gaps allowed
 *
 * maintain: false  -> infotype is display-only in this app. Infotype 0000 is read-only
 *                     here because actions are normally executed with PA40; set it to
 *                     true if you want to maintain it directly (like PA30 allows).
 */
sap.ui.define([], function () {
    "use strict";

    var FOREVER = "9999-12-31";

    var LISTS = {
        massn: [
            ["01", "Hiring"],
            ["02", "Organizational reassignment"],
            ["03", "Change in pay"],
            ["10", "Leaving"]
        ],
        massg: [
            ["01", "New hire"],
            ["02", "Restructuring"],
            ["03", "Annual review"],
            ["10", "Resignation"]
        ],
        stat2: [
            ["3", "Active"],
            ["2", "Retiree"],
            ["1", "Inactive"],
            ["0", "Withdrawn"]
        ],
        bukrs: [
            ["1000", "Sample Corp Korea"],
            ["2000", "Sample Corp Japan"]
        ],
        werks: [
            ["1000", "Seoul"],
            ["1100", "Busan"],
            ["1200", "Daegu"]
        ],
        btrtl: [
            ["0001", "Office"],
            ["0002", "Plant"]
        ],
        persg: [
            ["1", "Active"],
            ["2", "Retiree"],
            ["9", "External"]
        ],
        persk: [
            ["K1", "Regular employee"],
            ["K2", "Contract employee"]
        ],
        orgeh: [
            ["50000010", "HR Department"],
            ["50000020", "IT Department"],
            ["50000030", "Finance Department"],
            ["50000040", "Sales Department"]
        ],
        plans: [
            ["60000101", "HR Manager"],
            ["60000102", "Recruiter"],
            ["60000201", "Software Engineer"],
            ["60000202", "IT Architect"],
            ["60000301", "Accountant"],
            ["60000401", "Sales Lead"],
            ["60000402", "Account Executive"]
        ],
        stell: [
            ["70000001", "Manager"],
            ["70000002", "Specialist"],
            ["70000003", "Engineer"]
        ],
        kostl: [
            ["1000100", "HR"],
            ["1000200", "IT"],
            ["1000300", "Finance"],
            ["1000400", "Sales"]
        ],
        abkrs: [
            ["K1", "Monthly payroll Korea"]
        ],
        anred: [
            ["1", "Mr."],
            ["2", "Ms."]
        ],
        gesch: [
            ["1", "Male"],
            ["2", "Female"]
        ],
        natio: [
            ["KR", "Korea"],
            ["US", "United States"],
            ["JP", "Japan"],
            ["DE", "Germany"]
        ],
        sprsl: [
            ["KO", "Korean"],
            ["EN", "English"],
            ["JA", "Japanese"]
        ],
        famst: [
            ["0", "Single"],
            ["1", "Married"],
            ["2", "Widowed"],
            ["3", "Divorced"]
        ],
        subty0006: [
            ["1", "Permanent residence"],
            ["2", "Temporary residence"],
            ["3", "Emergency address"]
        ],
        land1: [
            ["KR", "Korea"],
            ["US", "United States"],
            ["JP", "Japan"],
            ["DE", "Germany"]
        ]
    };

    var INFOTYPES = [
        {
            id: "0000",
            tc: "1",
            maintain: false,
            subtypeList: null,
            fields: [
                { name: "massn", type: "select", list: "massn", required: true, table: true },
                { name: "massg", type: "select", list: "massg", required: false, table: true },
                { name: "stat2", type: "select", list: "stat2", required: true, table: true }
            ]
        },
        {
            id: "0001",
            tc: "1",
            maintain: true,
            subtypeList: null,
            fields: [
                { name: "bukrs", type: "select", list: "bukrs", required: true, table: false },
                { name: "werks", type: "select", list: "werks", required: true, table: true },
                { name: "btrtl", type: "select", list: "btrtl", required: true, table: false },
                { name: "persg", type: "select", list: "persg", required: true, table: true },
                { name: "persk", type: "select", list: "persk", required: true, table: false },
                { name: "orgeh", type: "select", list: "orgeh", required: true, table: true },
                { name: "plans", type: "select", list: "plans", required: true, table: true },
                { name: "stell", type: "select", list: "stell", required: false, table: true },
                { name: "kostl", type: "select", list: "kostl", required: false, table: true },
                { name: "abkrs", type: "select", list: "abkrs", required: true, table: false }
            ]
        },
        {
            id: "0002",
            tc: "1",
            maintain: true,
            subtypeList: null,
            fields: [
                { name: "anred", type: "select", list: "anred", required: false, table: true },
                { name: "nachn", type: "text", required: true, table: true, maxLength: 40 },
                { name: "vorna", type: "text", required: true, table: true, maxLength: 40 },
                { name: "gbdat", type: "date", required: true, table: true },
                { name: "gesch", type: "select", list: "gesch", required: true, table: false },
                { name: "natio", type: "select", list: "natio", required: false, table: false },
                { name: "sprsl", type: "select", list: "sprsl", required: false, table: false },
                { name: "famst", type: "select", list: "famst", required: false, table: true },
                { name: "anzkd", type: "int", required: false, table: true }
            ]
        },
        {
            id: "0006",
            tc: "2",
            maintain: true,
            subtypeList: "subty0006",
            fields: [
                { name: "stras", type: "text", required: true, table: true, maxLength: 60 },
                { name: "ort01", type: "text", required: true, table: true, maxLength: 40 },
                { name: "pstlz", type: "text", required: false, table: true, maxLength: 10 },
                { name: "land1", type: "select", list: "land1", required: true, table: true },
                { name: "telnr", type: "text", required: false, table: false, maxLength: 20 }
            ]
        }
    ];

    function getInfotype(id) {
        for (var i = 0; i < INFOTYPES.length; i++) {
            if (INFOTYPES[i].id === id) {
                return INFOTYPES[i];
            }
        }
        return null;
    }

    function listItems(list) {
        return (LISTS[list] || []).map(function (e) {
            return { key: e[0], text: e[1] };
        });
    }

    function listText(list, key) {
        var items = LISTS[list] || [];
        for (var i = 0; i < items.length; i++) {
            if (items[i][0] === key) {
                return items[i][1];
            }
        }
        return key === undefined || key === null ? "" : String(key);
    }

    return {
        FOREVER: FOREVER,
        INFOTYPES: INFOTYPES,
        get: getInfotype,
        listItems: listItems,
        listText: listText
    };
});
