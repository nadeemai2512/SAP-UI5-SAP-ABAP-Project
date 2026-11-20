sap.ui.define([], function () {
  "use strict";

  var BASE = "/sap/zproducts";

  /* ---------- shared validation (mirrors ZCL_PRODUCT_HTTP=>VALIDATE) ---------- */
  function validate(p) {
    if (!p.name || !String(p.name).trim()) { return "Name is required"; }
    if (Number(p.price) < 0) { return "Price must not be negative"; }
    if (Number(p.stock) < 0) { return "Stock must not be negative"; }
    return "";
  }

  /* ---------- real backend: ABAP ICF service ---------- */
  function request(method, query, body) {
    var url = BASE + (query ? "?" + query : "");
    var opts = {
      method: method,
      credentials: "same-origin",
      headers: { "Accept": "application/json", "Content-Type": "application/json" }
    };
    if (body !== undefined) { opts.body = JSON.stringify(body); }
    return fetch(url, opts).then(function (res) {
      return res.text().then(function (text) {
        var data = null;
        if (text) {
          try { data = JSON.parse(text); } catch (e) { data = null; }
        }
        if (!res.ok) {
          throw new Error((data && data.error) || (res.status + " " + res.statusText));
        }
        return data;
      });
    });
  }

  var abap = {
    getAll: function () { return request("GET"); },
    create: function (p) { return request("POST", "", p); },
    update: function (id, p) { return request("PUT", "id=" + encodeURIComponent(id), p); },
    remove: function (id) { return request("DELETE", "id=" + encodeURIComponent(id)); },
    restock: function (id, amount) {
      return request("POST", "id=" + encodeURIComponent(id) + "&action=restock&amount=" + amount);
    }
  };

  /* ---------- in-memory mock (demo mode, same contract as the ABAP service) ---------- */
  var seq = 100;
  var store = [
    { productId: "P001", name: "Laptop Pro 15", description: "15 inch business laptop", category: "Computers", price: 1499, currency: "EUR", stock: 25 },
    { productId: "P002", name: "Wireless Mouse", description: "Ergonomic bluetooth mouse", category: "Accessories", price: 29.9, currency: "EUR", stock: 150 },
    { productId: "P003", name: "USB-C Dock", description: "10-in-1 docking station", category: "Accessories", price: 89, currency: "EUR", stock: 4 },
    { productId: "P004", name: "27 inch Monitor", description: "4K IPS display", category: "Displays", price: 399, currency: "EUR", stock: 0 },
    { productId: "P005", name: "Mechanical Keyboard", description: "Hot-swappable keyboard", category: "Accessories", price: 119.5, currency: "EUR", stock: 60 }
  ];

  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function find(id) {
    return store.filter(function (p) { return p.productId === id; })[0];
  }
  function notFound(id) { return Promise.reject(new Error("Product " + id + " not found")); }

  var mock = {
    getAll: function () {
      var rows = clone(store);
      rows.sort(function (a, b) { return a.name.localeCompare(b.name); });
      return Promise.resolve(rows);
    },
    create: function (p) {
      var msg = validate(p);
      if (msg) { return Promise.reject(new Error(msg)); }
      var row = {
        productId: "P" + (++seq),
        name: p.name,
        description: p.description || "",
        category: p.category || "",
        price: Number(p.price) || 0,
        currency: p.currency || "EUR",
        stock: Number(p.stock) || 0
      };
      store.push(row);
      return Promise.resolve(clone(row));
    },
    update: function (id, p) {
      var row = find(id);
      if (!row) { return notFound(id); }
      var merged = Object.assign({}, row, p, { productId: id });
      var msg = validate(merged);
      if (msg) { return Promise.reject(new Error(msg)); }
      Object.assign(row, merged);
      return Promise.resolve(clone(row));
    },
    remove: function (id) {
      var row = find(id);
      if (!row) { return notFound(id); }
      store.splice(store.indexOf(row), 1);
      return Promise.resolve(null);
    },
    restock: function (id, amount) {
      var row = find(id);
      if (!row) { return notFound(id); }
      if (!(amount > 0)) { return Promise.reject(new Error("Amount must be greater than 0")); }
      row.stock += amount;
      return Promise.resolve(clone(row));
    }
  };

  var useMock = false;

  return {
    setMock: function (b) { useMock = !!b; },
    isMock: function () { return useMock; },
    validate: validate,
    getAll: function () { return (useMock ? mock : abap).getAll(); },
    create: function (p) { return (useMock ? mock : abap).create(p); },
    update: function (id, p) { return (useMock ? mock : abap).update(id, p); },
    remove: function (id) { return (useMock ? mock : abap).remove(id); },
    restock: function (id, n) { return (useMock ? mock : abap).restock(id, n); }
  };
});
