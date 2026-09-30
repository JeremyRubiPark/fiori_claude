sap.ui.define([
    "./BaseController",
    "sap/ui/model/json/JSONModel",
    "sap/m/Dialog",
    "sap/m/Button",
    "sap/m/Table",
    "sap/m/Column",
    "sap/m/ColumnListItem",
    "sap/m/Text",
    "sap/m/Title",
    "sap/m/Select",
    "sap/m/Input",
    "sap/m/DatePicker",
    "sap/m/Label",
    "sap/m/MessageStrip",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "sap/m/OverflowToolbar",
    "sap/m/ToolbarSpacer",
    "sap/ui/core/Item",
    "sap/ui/layout/form/SimpleForm",
    "sap/uxap/ObjectPageSection",
    "sap/uxap/ObjectPageSubSection",
    "../model/PALogic",
    "../model/infotypes",
    "../model/formatter"
], function (BaseController, JSONModel, Dialog, Button, Table, Column, ColumnListItem, Text, Title, Select,
    Input, DatePicker, Label, MessageStrip, MessageBox, MessageToast, OverflowToolbar, ToolbarSpacer, Item,
    SimpleForm, ObjectPageSection, ObjectPageSubSection, PALogic, IT, formatter) {
    "use strict";

    return BaseController.extend("zpa.hr.controller.Employee", {
        formatter: formatter,

        onInit: function () {
            this._pernr = null;
            this._tables = {};
            this.setModel(new JSONModel({}), "emp");
            this.setModel(new JSONModel({}), "data");
            var period = {};
            IT.INFOTYPES.forEach(function (def) {
                period[def.id] = "current";
            });
            this.setModel(new JSONModel({
                keyDate: PALogic.today(),
                editing: false,
                user: PALogic.USER,
                period: period
            }), "ui");
            this._buildSections();
            this.getRouter().getRoute("employee").attachPatternMatched(this._onMatched, this);
        },

        onExit: function () {
            this._release();
        },

        // ------------------------------------------------------------- navigation / lock
        _onMatched: function (oEvent) {
            var pernr = oEvent.getParameter("arguments").pernr;
            this._release();
            this._pernr = pernr;
            var ui = this.getModel("ui");
            ui.setProperty("/editing", false);
            ui.setProperty("/keyDate", PALogic.today());
            if (!PALogic.getEmployee(pernr, PALogic.today())) {
                MessageBox.error(this.getText("msg_EMPLOYEE_NOT_FOUND", [pernr]), {
                    onClose: this.onNavBack.bind(this)
                });
                return;
            }
            this._refresh();
        },

        _release: function () {
            if (this._pernr && this.getModel("ui") && this.getModel("ui").getProperty("/editing")) {
                PALogic.unlock(this._pernr);
            }
            if (this.getModel("ui")) {
                this.getModel("ui").setProperty("/editing", false);
            }
        },

        onNavBack: function () {
            this._release();
            this.getRouter().navTo("search");
        },

        onToggleEdit: function () {
            var ui = this.getModel("ui");
            if (ui.getProperty("/editing")) {
                PALogic.unlock(this._pernr);
                ui.setProperty("/editing", false);
            } else {
                var res = PALogic.lock(this._pernr);
                if (!res.ok) {
                    MessageBox.error(this._messages(res.errors).join("\n"));
                    this._refresh();
                    return;
                }
                ui.setProperty("/editing", true);
            }
            this._refresh();
        },

        onKeyDateChange: function () {
            var ui = this.getModel("ui");
            if (!PALogic.isIso(ui.getProperty("/keyDate"))) {
                ui.setProperty("/keyDate", PALogic.today());
            }
            this._refresh();
        },

        onPeriodChange: function () {
            this._refresh();
        },

        // ------------------------------------------------------------- display
        _buildSections: function () {
            var that = this;
            var layout = this.byId("opl");
            IT.INFOTYPES.forEach(function (def) {
                var table = that._createTable(def);
                that._tables[def.id] = table;
                // the toolbar is the table's own header, so toolbar and table stay in one block
                // (separate blocks of a sub section are laid out side by side)
                table.setHeaderToolbar(that._createToolbar(def));
                var title = that.getText("it_" + def.id);
                layout.addSection(new ObjectPageSection({
                    title: def.id + " " + title,
                    subSections: [new ObjectPageSubSection({ blocks: [table] })]
                }));
            });
        },

        _createToolbar: function (def) {
            var that = this;
            var maintainable = def.maintain !== false;
            var editingBinding = "{= ${ui>/editing} }";
            var bar = new OverflowToolbar({
                content: [
                    new Title({ text: this.getText("records") }),
                    new Select({
                        width: "14rem",
                        selectedKey: "{ui>/period/" + def.id + "}",
                        change: this.onPeriodChange.bind(this),
                        items: [
                            new Item({ key: "current", text: this.getText("periodCurrent") }),
                            new Item({ key: "all", text: this.getText("periodAll") })
                        ]
                    }),
                    new ToolbarSpacer()
                ]
            });
            if (!maintainable) {
                bar.addContent(new Text({ text: this.getText("readOnlyInfotype") }));
                return bar;
            }
            function btn(key, icon, handler, visible) {
                return new Button({
                    text: that.getText(key),
                    icon: icon,
                    visible: visible === undefined ? editingBinding : visible,
                    press: handler
                });
            }
            bar.addContent(btn("create", "sap-icon://add", function () { that._openEditDialog(def, "create"); }));
            bar.addContent(btn("copy", "sap-icon://duplicate", function () { that._openEditDialog(def, "copy"); }));
            bar.addContent(btn("change", "sap-icon://edit", function () { that._openEditDialog(def, "change"); }));
            if (def.tc === "2") {
                bar.addContent(btn("delimit", "sap-icon://scissors", function () { that._openDelimitDialog(def); }));
            }
            bar.addContent(btn("delete", "sap-icon://delete", function () { that._confirmDelete(def); }));
            return bar;
        },

        _columns: function (def) {
            var cols = [{ name: "begda", date: true }, { name: "endda", date: true }];
            if (def.subtypeList) {
                cols.push({ name: "subty" });
            }
            def.fields.forEach(function (f) {
                cols.push({ name: f.name, optional: !f.table });
            });
            cols.push({ name: "aedtm", date: true, optional: true });
            cols.push({ name: "uname", optional: true });
            return cols;
        },

        _createTable: function (def) {
            var that = this;
            var cols = this._columns(def);
            var table = new Table({
                mode: {
                    path: "ui>/editing",
                    formatter: function (editing) {
                        return def.maintain !== false && editing ? "SingleSelectLeft" : "None";
                    }
                },
                noDataText: this.getText("noRecords"),
                items: {
                    path: "data>/it/" + def.id,
                    template: new ColumnListItem({
                        highlight: { path: "data>_valid", formatter: function (v) { return v ? "Information" : "None"; } },
                        cells: cols.map(function (c) {
                            return new Text({ text: "{data>disp/" + c.name + "}" });
                        })
                    }),
                    templateShareable: false
                }
            });
            cols.forEach(function (c) {
                table.addColumn(new Column({
                    minScreenWidth: c.optional ? "Desktop" : undefined,
                    demandPopin: !!c.optional,
                    header: new Text({ text: that.getText("f_" + c.name) })
                }));
            });
            return table;
        },

        _display: function (def, rec) {
            var disp = {};
            var all = this._columns(def);
            var fieldDefs = {};
            def.fields.forEach(function (f) { fieldDefs[f.name] = f; });
            all.forEach(function (c) {
                var v = rec[c.name];
                var f = fieldDefs[c.name];
                if (c.name === "subty") {
                    disp.subty = v ? IT.listText(def.subtypeList, v) + " (" + v + ")" : "";
                } else if (c.date || (f && f.type === "date")) {
                    disp[c.name] = v === PALogic.FOREVER ? v : formatter.fmtDate(v);
                } else if (f && f.type === "select") {
                    disp[c.name] = v ? IT.listText(f.list, v) + " (" + v + ")" : "";
                } else {
                    disp[c.name] = v === undefined || v === null ? "" : String(v);
                }
            });
            rec.disp = disp;
            return rec;
        },

        _refresh: function () {
            var that = this;
            var ui = this.getModel("ui").getData();
            this.getModel("emp").setData(PALogic.getEmployee(this._pernr, ui.keyDate) || {});
            var data = { it: {} };
            IT.INFOTYPES.forEach(function (def) {
                var rows = PALogic.getRecords(that._pernr, def.id, {
                    period: ui.period[def.id],
                    keyDate: ui.keyDate
                });
                data.it[def.id] = rows.map(function (r) { return that._display(def, r); });
            });
            this.getModel("data").setData(data);
            Object.keys(this._tables).forEach(function (id) {
                that._tables[id].removeSelections(true);
            });
        },

        _selected: function (def) {
            var item = this._tables[def.id].getSelectedItem();
            if (!item) {
                MessageToast.show(this.getText("selectRecord"));
                return null;
            }
            return PALogic.getRecord(item.getBindingContext("data").getProperty("id"));
        },

        // ------------------------------------------------------------- messages
        _messages: function (list) {
            var that = this;
            return (list || []).map(function (m) {
                var params = (m.params || []).map(function (p, i) {
                    if (typeof p === "string" && PALogic.isIso(p)) {
                        return p === PALogic.FOREVER ? p : formatter.fmtDate(p);
                    }
                    var isField = i === 0 && /^(REQUIRED|INVALID_VALUE|INVALID_DATE|INVALID_NUMBER|TOO_LONG)$/.test(m.code);
                    return isField ? that.getText("f_" + p) : p;
                });
                return that.getText("msg_" + m.code, params);
            });
        },

        // ------------------------------------------------------------- create / copy / change
        _openEditDialog: function (def, action) {
            var that = this;
            var source = null;
            if (action !== "create") {
                source = this._selected(def);
                if (!source) {
                    return;
                }
            }
            var values = {};
            if (action === "create") {
                values.begda = PALogic.today();
                values.endda = PALogic.FOREVER;
                values.subty = def.subtypeList ? IT.listItems(def.subtypeList)[0].key : "";
                // start from the record valid at the key date (like "Create" in PA30 with a current record)
                var cur = PALogic.getRecords(this._pernr, def.id, { period: "current", keyDate: PALogic.today() })[0];
                if (cur) {
                    def.fields.forEach(function (f) { values[f.name] = cur[f.name]; });
                }
            } else if (action === "copy") {
                values = PALogic.copyDefaults(source.id);
            } else {
                values = source;
            }
            values = JSON.parse(JSON.stringify(values));
            var model = new JSONModel(values);
            var locked = action === "change";

            var form = new SimpleForm({ editable: true, layout: "ResponsiveGridLayout", labelSpanL: 4, labelSpanM: 4 });
            var error = new MessageStrip({ type: "Error", showIcon: true, visible: false, class: "sapUiSmallMarginBottom" });

            function label(name, required) {
                return new Label({ text: that.getText("f_" + name), required: !!required });
            }
            if (def.subtypeList) {
                form.addContent(label("subty", true));
                form.addContent(new Select({
                    selectedKey: "{/subty}",
                    enabled: !locked,
                    items: IT.listItems(def.subtypeList).map(function (i) {
                        return new Item({ key: i.key, text: i.text + " (" + i.key + ")" });
                    })
                }));
            }
            form.addContent(label("begda", true));
            form.addContent(new DatePicker({ value: "{/begda}", valueFormat: "yyyy-MM-dd", enabled: !locked }));
            form.addContent(label("endda", true));
            form.addContent(new DatePicker({ value: "{/endda}", valueFormat: "yyyy-MM-dd", enabled: !locked }));
            def.fields.forEach(function (f) {
                form.addContent(label(f.name, f.required));
                if (f.type === "select") {
                    var items = IT.listItems(f.list).map(function (i) {
                        return new Item({ key: i.key, text: i.text + " (" + i.key + ")" });
                    });
                    if (!f.required) {
                        items.unshift(new Item({ key: "", text: "" }));
                    }
                    form.addContent(new Select({ selectedKey: "{/" + f.name + "}", items: items, forceSelection: false }));
                } else if (f.type === "date") {
                    form.addContent(new DatePicker({ value: "{/" + f.name + "}", valueFormat: "yyyy-MM-dd" }));
                } else {
                    form.addContent(new Input({
                        value: "{/" + f.name + "}",
                        maxLength: f.maxLength,
                        type: f.type === "int" ? "Number" : "Text"
                    }));
                }
            });

            var dialog = new Dialog({
                title: this.getText("dlg_" + action) + " - " + def.id + " " + this.getText("it_" + def.id),
                contentWidth: "32rem",
                content: [error, form],
                beginButton: new Button({
                    text: this.getText("save"),
                    type: "Emphasized",
                    press: function () {
                        var v = model.getData();
                        var res;
                        if (action === "change") {
                            res = PALogic.change(source.id, v);
                        } else {
                            v.pernr = that._pernr;
                            v.infty = def.id;
                            res = PALogic.create(v);
                        }
                        if (!res.ok) {
                            error.setText(that._messages(res.errors).join("\n"));
                            error.setVisible(true);
                            return;
                        }
                        dialog.close();
                        MessageToast.show(that._messages(res.messages).join("\n"), { duration: 5000, width: "30em" });
                        that._refresh();
                    }
                }),
                endButton: new Button({ text: this.getText("cancel"), press: function () { dialog.close(); } }),
                afterClose: function () { dialog.destroy(); }
            });
            dialog.setModel(model);
            dialog.setModel(this.getModel("i18n"), "i18n");
            this.getView().addDependent(dialog);
            dialog.open();
        },

        // ------------------------------------------------------------- delimit
        _openDelimitDialog: function (def) {
            var that = this;
            var rec = this._selected(def);
            if (!rec) {
                return;
            }
            var model = new JSONModel({ endda: PALogic.today() <= rec.begda ? rec.begda : PALogic.today() });
            var error = new MessageStrip({ type: "Error", showIcon: true, visible: false, class: "sapUiSmallMarginBottom" });
            var dialog = new Dialog({
                title: this.getText("dlg_delimit"),
                contentWidth: "24rem",
                content: [error, new SimpleForm({
                    editable: true,
                    layout: "ResponsiveGridLayout",
                    content: [
                        new Label({ text: this.getText("f_endda"), required: true }),
                        new DatePicker({ value: "{/endda}", valueFormat: "yyyy-MM-dd" })
                    ]
                })],
                beginButton: new Button({
                    text: this.getText("save"),
                    type: "Emphasized",
                    press: function () {
                        var res = PALogic.delimit(rec.id, model.getProperty("/endda"));
                        if (!res.ok) {
                            error.setText(that._messages(res.errors).join("\n"));
                            error.setVisible(true);
                            return;
                        }
                        dialog.close();
                        MessageToast.show(that._messages(res.messages).join("\n"));
                        that._refresh();
                    }
                }),
                endButton: new Button({ text: this.getText("cancel"), press: function () { dialog.close(); } }),
                afterClose: function () { dialog.destroy(); }
            });
            dialog.setModel(model);
            this.getView().addDependent(dialog);
            dialog.open();
        },

        // ------------------------------------------------------------- delete
        _confirmDelete: function (def) {
            var that = this;
            var rec = this._selected(def);
            if (!rec) {
                return;
            }
            MessageBox.confirm(this.getText("confirmDelete", [formatter.fmtDate(rec.begda), rec.endda === PALogic.FOREVER ? rec.endda : formatter.fmtDate(rec.endda)]), {
                actions: [MessageBox.Action.DELETE, MessageBox.Action.CANCEL],
                emphasizedAction: MessageBox.Action.DELETE,
                onClose: function (action) {
                    if (action !== MessageBox.Action.DELETE) {
                        return;
                    }
                    var res = PALogic.remove(rec.id);
                    if (!res.ok) {
                        MessageBox.error(that._messages(res.errors).join("\n"));
                        return;
                    }
                    MessageToast.show(that._messages(res.messages).join("\n"), { duration: 5000, width: "30em" });
                    that._refresh();
                }
            });
        }
    });
});
