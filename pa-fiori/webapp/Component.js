sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/model/json/JSONModel"
], function (UIComponent, JSONModel) {
    "use strict";

    return UIComponent.extend("zpa.hr.Component", {
        metadata: {
            manifest: "json"
        },

        init: function () {
            UIComponent.prototype.init.apply(this, arguments);

            // "display" = PA20 behaviour, "maintain" = PA30 behaviour.
            // A Fiori Launchpad tile can preselect it with the parameter ?mode=maintain
            var mode = "display";
            var data = this.getComponentData();
            var params = data && data.startupParameters;
            if (params && params.mode && params.mode[0] === "maintain") {
                mode = "maintain";
            }
            this.setModel(new JSONModel({ mode: mode }), "app");

            this.getRouter().initialize();
        }
    });
});
