sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/Fragment",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/ui/model/json/JSONModel",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "com/demo/abapproducts/model/ProductService"
], function (Controller, Fragment, Filter, FilterOperator, JSONModel, MessageToast, MessageBox, ProductService) {
  "use strict";

  return Controller.extend("com.demo.abapproducts.controller.Main", {

    onInit: function () {
      var bMock = new URLSearchParams(window.location.search).get("mock") === "true";
      ProductService.setMock(bMock);

      this.getView().setModel(new JSONModel({ items: [] }), "products");
      this.getView().setModel(new JSONModel({ busy: false, mock: bMock, count: 0, value: "0.00", low: 0 }), "view");
      this.getView().setModel(new JSONModel({}), "form");

      this._load();
    },

    _t: function (sKey) {
      return this.getView().getModel("i18n").getResourceBundle().getText(sKey);
    },

    _error: function (e) {
      MessageBox.error((e && e.message) || this._t("errorGeneric"));
    },

    _setBusy: function (b) { this.getView().getModel("view").setProperty("/busy", b); },

    _load: function () {
      var that = this;
      this._setBusy(true);
      return ProductService.getAll().then(function (aItems) {
        aItems = aItems || [];
        that.getView().getModel("products").setProperty("/items", aItems);
        var fValue = aItems.reduce(function (s, p) { return s + (p.price || 0) * (p.stock || 0); }, 0);
        var oView = that.getView().getModel("view");
        oView.setProperty("/count", aItems.length);
        oView.setProperty("/value", fValue.toFixed(2));
        oView.setProperty("/low", aItems.filter(function (p) { return p.stock < 10; }).length);
      }).catch(function (e) {
        MessageBox.error(that._t("loadError") + ": " + e.message);
      }).then(function () { that._setBusy(false); });
    },

    _selected: function () {
      var oItem = this.byId("productTable").getSelectedItem();
      if (!oItem) { MessageToast.show(this._t("selectOne")); return null; }
      return oItem.getBindingContext("products").getObject();
    },

    onSearch: function (oEvent) {
      var sQuery = oEvent.getParameter("query");
      var aFilters = sQuery ? [new Filter({
        filters: [
          new Filter("name", FilterOperator.Contains, sQuery),
          new Filter("category", FilterOperator.Contains, sQuery)
        ],
        and: false
      })] : [];
      this.byId("productTable").getBinding("items").filter(aFilters);
    },

    _openDialog: function () {
      var oView = this.getView();
      if (!this._pDialog) {
        this._pDialog = Fragment.load({ id: oView.getId(), name: "com.demo.abapproducts.fragment.ProductDialog", controller: this })
          .then(function (oDialog) { oView.addDependent(oDialog); return oDialog; });
      }
      return this._pDialog.then(function (oDialog) { oDialog.open(); });
    },

    onAdd: function () {
      this._editId = null;
      this.getView().getModel("form").setData({
        title: this._t("addProduct"), name: "", description: "", category: "", price: "", currency: "EUR", stock: "0"
      });
      this._openDialog();
    },

    onEdit: function () {
      var o = this._selected();
      if (!o) { return; }
      this._editId = o.productId;
      this.getView().getModel("form").setData({
        title: this._t("editProduct"), name: o.name, description: o.description, category: o.category,
        price: String(o.price), currency: o.currency, stock: String(o.stock)
      });
      this._openDialog();
    },

    onCancel: function () { this._pDialog.then(function (d) { d.close(); }); },

    onSave: function () {
      var that = this, f = this.getView().getModel("form").getData();
      var oPayload = {
        name: (f.name || "").trim(),
        description: f.description || "",
        category: f.category || "",
        price: parseFloat(f.price) || 0,
        currency: (f.currency || "EUR").toUpperCase(),
        stock: parseInt(f.stock, 10) || 0
      };
      var sMsg = ProductService.validate(oPayload);
      if (sMsg) { MessageBox.warning(sMsg); return; }

      var bEdit = !!this._editId;
      var pCall = bEdit ? ProductService.update(this._editId, oPayload) : ProductService.create(oPayload);
      this._setBusy(true);
      pCall.then(function () {
        that._pDialog.then(function (d) { d.close(); });
        MessageToast.show(that._t(bEdit ? "updated" : "created"));
        return that._load();
      }).catch(function (e) {
        that._setBusy(false);
        that._error(e);
      });
    },

    onDelete: function () {
      var that = this, o = this._selected();
      if (!o) { return; }
      MessageBox.confirm(this._t("confirmDelete"), {
        onClose: function (sAction) {
          if (sAction !== MessageBox.Action.OK) { return; }
          that._setBusy(true);
          ProductService.remove(o.productId).then(function () {
            MessageToast.show(that._t("deleted"));
            return that._load();
          }).catch(function (e) { that._setBusy(false); that._error(e); });
        }
      });
    },

    onRestock: function () {
      var that = this, o = this._selected();
      if (!o) { return; }
      this._setBusy(true);
      ProductService.restock(o.productId, 10).then(function () {
        MessageToast.show(that._t("restocked"));
        return that._load();
      }).catch(function (e) { that._setBusy(false); that._error(e); });
    }
  });
});
