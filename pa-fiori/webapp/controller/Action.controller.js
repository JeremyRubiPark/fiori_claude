sap.ui.define([
    "./BaseController",
    "sap/ui/model/json/JSONModel",
    "sap/m/Panel",
    "sap/m/Select",
    "sap/m/Input",
    "sap/m/DatePicker",
    "sap/m/Label",
    "sap/m/MessageBox",
    "sap/base/security/encodeXML",
    "sap/ui/core/Item",
    "sap/ui/layout/form/SimpleForm",
    "../model/PALogic",
    "../model/infotypes"
], function (BaseController, JSONModel, Panel, Select, Input, DatePicker, Label, MessageBox, encodeXML, Item,
    SimpleForm, PALogic, IT) {
    "use strict";

    function asHtml(lines) {
        return lines.map(encodeXML).join("<br>");
    }

    function withEmpty(items) {
        return [{ key: "", text: "" }].concat(items);
    }

    return BaseController.extend("zpa.hr.controller.Action", {
        onInit: function () {
            this.setModel(new JSONModel({}), "act");
            this.getRouter().getRoute("action").attachPatternMatched(this._onMatched, this);
        },

        _onMatched: function (oEvent) {
            var pernr = oEvent.getParameter("arguments").pernr || "";
            var actionList = IT.ACTIONS.map(function (a) {
                return { key: a.id, text: IT.listText("massn", a.id) + " (" + a.id + ")" };
            });
            this.getModel("act").setData({
                actionList: actionList,
                reasonList: withEmpty(IT.listItems("massg")),
                massn: pernr ? "02" : "01",
                massg: "",
                pernr: pernr,
                empName: "",
                begda: PALogic.today(),
                isHire: !pernr,
                hasSteps: false,
                steps: {}
            });
            this._rebuild();
        },

        onNavBack: function () {
            var pernr = this.getModel("act").getProperty("/pernr");
            var isHire = this.getModel("act").getProperty("/isHire");
            if (pernr && !isHire && PALogic.getEmployee(pernr, PALogic.today())) {
                this.getRouter().navTo("employee", { pernr: pernr });
            } else {
                this.getRouter().navTo("search");
            }
        },

        onActionChange: function () {
            this._rebuild();
        },

        onPernrChange: function () {
            this._rebuild();
        },

        /** reads the start values for the chosen action and builds one panel per infotype */
        _rebuild: function () {
            var model = this.getModel("act");
            var action = IT.getAction(model.getProperty("/massn"));
            var isHire = !!(action && action.newEmployee);
            var pernr = isHire ? "" : (model.getProperty("/pernr") || "").trim();
            var emp = pernr ? PALogic.getEmployee(pernr, model.getProperty("/begda")) : null;
            model.setProperty("/isHire", isHire);
            if (isHire) {
                model.setProperty("/pernr", "");
            }
            model.setProperty("/empName", emp ? emp.fullName : "");

            var container = this.byId("steps");
            container.destroyItems();
            var steps = {};
            if (action && (isHire || emp)) {
                var d = PALogic.actionDefaults(action.id, pernr, model.getProperty("/begda"));
                steps = d ? d.steps : {};
                action.steps.forEach(function (infty) {
                    container.addItem(this._createPanel(IT.get(infty)));
                }, this);
            }
            model.setProperty("/steps", steps);
            model.setProperty("/hasSteps", !!(action && action.steps.length && (isHire || emp)));
        },

        _createPanel: function (def) {
            var that = this;
            var prefix = "act>/steps/" + def.id + "/";
            var form = new SimpleForm({ editable: true, layout: "ResponsiveGridLayout", labelSpanL: 3, labelSpanM: 3 });

            function label(name, required) {
                return new Label({ text: that.getText("f_" + name), required: !!required });
            }
            function options(list) {
                return IT.listItems(list).map(function (i) {
                    return new Item({ key: i.key, text: i.text + " (" + i.key + ")" });
                });
            }
            if (def.subtypeList) {
                form.addContent(label("subty", true));
                form.addContent(new Select({ selectedKey: "{" + prefix + "subty}", items: options(def.subtypeList) }));
            }
            def.fields.forEach(function (f) {
                form.addContent(label(f.name, f.required));
                if (f.type === "select") {
                    var items = options(f.list);
                    if (!f.required) {
                        items.unshift(new Item({ key: "", text: "" }));
                    }
                    form.addContent(new Select({ selectedKey: "{" + prefix + f.name + "}", items: items, forceSelection: false }));
                } else if (f.type === "date") {
                    form.addContent(new DatePicker({ value: "{" + prefix + f.name + "}", valueFormat: "yyyy-MM-dd", displayFormat: "yyyy.MM.dd" }));
                } else {
                    form.addContent(new Input({
                        value: "{" + prefix + f.name + "}",
                        maxLength: f.maxLength,
                        type: f.type === "int" ? "Number" : "Text"
                    }));
                }
            });
            return new Panel({
                headerText: def.id + " " + this.getText("it_" + def.id),
                class: "sapUiResponsiveMargin",
                width: "auto",
                content: [form]
            });
        },

        onExecute: function () {
            var that = this;
            var d = this.getModel("act").getData();
            var res = PALogic.executeAction({
                massn: d.massn,
                massg: d.massg,
                pernr: (d.pernr || "").trim(),
                begda: d.begda,
                steps: JSON.parse(JSON.stringify(d.steps || {}))
            });
            if (!res.ok) {
                MessageBox.error(this.getText("actionFailed"), {
                    details: asHtml(this.translateMessages(res.errors))
                });
                return;
            }
            MessageBox.success(this.getText("actionSaved"), {
                details: asHtml(this.translateMessages(res.messages)),
                onClose: function () {
                    that.getRouter().navTo("employee", { pernr: res.pernr });
                }
            });
        }
    });
});
