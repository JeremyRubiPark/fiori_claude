sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "../model/OrgLogic",
    "../model/formatter"
], function (Controller, JSONModel, OrgLogic, formatter) {
    "use strict";

    return Controller.extend("zec.org.controller.OrgChart", {
        formatter: formatter,

        onInit: function () {
            this.getView().setModel(new JSONModel({ nodes: [] }), "org");
            this.getView().setModel(new JSONModel({}), "sel");
            this.getView().setModel(new JSONModel({ rows: [] }), "members");
            this.getView().setModel(new JSONModel({
                keyDate: OrgLogic.today(),
                query: "",
                includeSub: false
            }), "ui");
            this._loadTree();
        },

        _date: function () {
            var d = this.getView().getModel("ui").getProperty("/keyDate");
            return OrgLogic.isIso(d) ? d : OrgLogic.today();
        },

        _text: function (key, args) {
            return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(key, args);
        },

        /** reloads the tree for the key date / search text; the selection is cleared */
        _loadTree: function () {
            var ui = this.getView().getModel("ui");
            var nodes = OrgLogic.getTree(this._date(), ui.getProperty("/query"));
            this.getView().getModel("org").setData({ nodes: nodes });
            this.getView().getModel("sel").setData({});
            this.getView().getModel("members").setData({ rows: [] });
            var tree = this.byId("tree");
            tree.removeSelections(true);
            // a search result is shown fully expanded so that every hit is visible
            tree.expandToLevel(ui.getProperty("/query") ? 99 : 1);
        },

        onSearch: function (oEvent) {
            this.getView().getModel("ui").setProperty("/query", oEvent.getParameter("query") || "");
            this._loadTree();
        },

        onKeyDateChange: function () {
            var ui = this.getView().getModel("ui");
            if (!OrgLogic.isIso(ui.getProperty("/keyDate"))) {
                ui.setProperty("/keyDate", OrgLogic.today());
            }
            this._loadTree();
        },

        onExpandAll: function () {
            this.byId("tree").expandToLevel(99);
        },

        onCollapseAll: function () {
            this.byId("tree").collapseAll();
        },

        onSelect: function (oEvent) {
            var item = oEvent.getParameter("listItem");
            var id = item.getBindingContext("org").getProperty("id");
            var unit = OrgLogic.getUnit(id, this._date());
            if (!unit) {
                this.getView().getModel("sel").setData({});
                return;
            }
            unit.pathText = unit.path.join(" > ");
            unit.validityText = formatter.fmtDate(unit.begda) + " - " +
                formatter.fmtDate(unit.endda);
            this.getView().getModel("sel").setData(unit);
            this._loadMembers();
        },

        onIncludeSubChange: function () {
            this._loadMembers();
        },

        _loadMembers: function () {
            var id = this.getView().getModel("sel").getProperty("/id");
            var include = this.getView().getModel("ui").getProperty("/includeSub");
            this.getView().getModel("members").setData({
                rows: id ? OrgLogic.getMembers(id, this._date(), include) : []
            });
        }
    });
});
