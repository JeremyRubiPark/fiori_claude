/**
 * Date display: every date in the app is shown as yyyy.mm.dd (independent of the browser locale).
 * Internally dates stay ISO strings (yyyy-MM-dd).
 */
sap.ui.define([], function () {
    "use strict";

    return {
        /** "2026-10-01" -> "2026.10.01"; anything else is returned unchanged */
        fmtDate: function (iso) {
            if (!iso || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
                return iso || "";
            }
            return iso.replace(/-/g, ".");
        }
    };
});
