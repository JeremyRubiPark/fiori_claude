sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/core/UIComponent"
], function (Controller, UIComponent) {
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

        getText: function (key, args) {
            return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(key, args);
        }
    });
});
