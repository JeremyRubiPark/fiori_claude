sap.ui.define([
    "sap/ui/core/format/DateFormat"
], function (DateFormat) {
    "use strict";

    var dateFormat;

    return {
        /** "2026-10-01" -> localized medium date; anything else is returned unchanged */
        fmtDate: function (iso) {
            if (!iso || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
                return iso || "";
            }
            if (!dateFormat) {
                dateFormat = DateFormat.getDateInstance({ style: "medium" });
            }
            var p = iso.split("-");
            return dateFormat.format(new Date(+p[0], +p[1] - 1, +p[2]));
        }
    };
});
