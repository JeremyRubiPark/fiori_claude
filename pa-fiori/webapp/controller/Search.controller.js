sap.ui.define([
    "./BaseController",
    "sap/ui/model/json/JSONModel",
    "../model/PALogic",
    "../model/infotypes",
    "../model/formatter"
], function (BaseController, JSONModel, PALogic, IT, formatter) {
    "use strict";

    return BaseController.extend("zpa.hr.controller.Search", {
        formatter: formatter,

        onInit: function () {
            var orgList = [{ key: "", text: "" }].concat(IT.listItems("orgeh"));
            this.setModel(new JSONModel({
                keyDate: PALogic.today(),
                pernr: "",
                name: "",
                orgeh: "",
                orgList: orgList
            }), "filter");
            this.setModel(new JSONModel({ rows: [] }), "results");
            this.onSearch();
        },

        onSearch: function () {
            var f = this.getModel("filter").getData();
            var keyDate = PALogic.isIso(f.keyDate) ? f.keyDate : PALogic.today();
            var rows = PALogic.searchEmployees({ pernr: f.pernr, name: f.name, orgeh: f.orgeh }, keyDate);
            this.getModel("results").setData({ rows: rows });
        },

        onReset: function () {
            var m = this.getModel("filter");
            m.setProperty("/keyDate", PALogic.today());
            m.setProperty("/pernr", "");
            m.setProperty("/name", "");
            m.setProperty("/orgeh", "");
            this.onSearch();
        },

        onPressEmployee: function (oEvent) {
            var ctx = oEvent.getSource().getBindingContext("results");
            this.getRouter().navTo("employee", { pernr: ctx.getProperty("pernr") });
        }
    });
});
