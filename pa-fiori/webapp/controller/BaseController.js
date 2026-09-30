sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/core/UIComponent",
    "../model/PALogic",
    "../model/formatter"
], function (Controller, UIComponent, PALogic, formatter) {
    "use strict";

    return Controller.extend("zpa.hr.controller.BaseController", {
        getRouter: function () {
            return UIComponent.getRouterFor(this);
        },

        getModel: function (name) {
            return this.getView().getModel(name);
        },

        setModel: function (model, name) {
            return this.getView().setModel(model, name);
        },

        /** translates service messages { code, params } with the i18n keys msg_<code> */
        translateMessages: function (list) {
            var that = this;
            return (list || []).map(function (m) {
                var params = (m.params || []).map(function (p, i) {
                    if (typeof p === "string" && PALogic.isIso(p)) {
                        return formatter.fmtDate(p);
                    }
                    var isField = i === 0 && /^(REQUIRED|INVALID_VALUE|INVALID_DATE|INVALID_NUMBER|TOO_LONG)$/.test(m.code);
                    return isField ? that.getText("f_" + p) : p;
                });
                var text = that.getText("msg_" + m.code, params);
                return m.infty ? m.infty + ": " + text : text;
            });
        },

        getText: function (key, args) {
            return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(key, args);
        }
    });
});
