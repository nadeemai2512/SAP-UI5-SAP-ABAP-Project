/* Run with: npm test  (plain Node 18+, no dependencies) */
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const http = require("http");

function loadService() {
  let mod;
  global.sap = { ui: { define: (deps, fn) => { mod = fn(); } } };
  const src = fs.readFileSync(path.join(__dirname, "../webapp/model/ProductService.js"), "utf8");
  new Function(src)();
  return mod;
}

async function testMock() {
  const S = loadService();
  S.setMock(true);
  let rows = await S.getAll();
  assert.strictEqual(rows.length, 5);
  assert.deepStrictEqual(rows.map(r => r.name), rows.map(r => r.name).slice().sort((a, b) => a.localeCompare(b)));

  const created = await S.create({ name: "Webcam", price: 49.9, stock: 3 });
  assert.ok(created.productId);
  assert.strictEqual((await S.getAll()).length, 6);

  await assert.rejects(() => S.create({ name: "", price: 1, stock: 1 }), /Name is required/);
  await assert.rejects(() => S.create({ name: "X", price: -1, stock: 1 }), /Price must not be negative/);
  await assert.rejects(() => S.create({ name: "X", price: 1, stock: -1 }), /Stock must not be negative/);

  const upd = await S.update(created.productId, { name: "Webcam HD", price: 59, stock: 3 });
  assert.strictEqual(upd.name, "Webcam HD");

  const rs = await S.restock(created.productId, 10);
  assert.strictEqual(rs.stock, 13);
  await assert.rejects(() => S.restock(created.productId, 0), /greater than 0/);

  await S.remove(created.productId);
  assert.strictEqual((await S.getAll()).length, 5);
  await assert.rejects(() => S.remove("nope"), /not found/);
  console.log("ok  mock service");
}

async function testHttp() {
  // fake server speaking the same protocol as ZCL_PRODUCT_HTTP
  const seen = [];
  const server = http.createServer((req, res) => {
    let body = "";
    req.on("data", c => body += c);
    req.on("end", () => {
      seen.push({ method: req.method, url: req.url, body: body ? JSON.parse(body) : null });
      res.setHeader("Content-Type", "application/json");
      if (req.url.includes("id=missing")) { res.statusCode = 404; return res.end(JSON.stringify({ error: "Product missing not found" })); }
      if (req.method === "DELETE") { res.statusCode = 204; return res.end(); }
      res.statusCode = req.method === "POST" && !req.url.includes("action") ? 201 : 200;
      res.end(JSON.stringify(req.method === "GET" && req.url === "/sap/zproducts" ? [{ productId: "1", name: "A" }] : { productId: "1", name: "A" }));
    });
  });
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const realFetch = global.fetch;
  global.fetch = (url, opts) => realFetch("http://localhost:" + port + url, opts);

  const S = loadService();
  S.setMock(false);
  assert.deepStrictEqual(await S.getAll(), [{ productId: "1", name: "A" }]);
  await S.create({ name: "A" });
  await S.update("1", { name: "A" });
  assert.strictEqual(await S.remove("1"), null);
  await S.restock("1", 10);
  await assert.rejects(() => S.update("missing", { name: "A" }), /Product missing not found/);

  assert.deepStrictEqual(seen.map(s => s.method + " " + s.url), [
    "GET /sap/zproducts",
    "POST /sap/zproducts",
    "PUT /sap/zproducts?id=1",
    "DELETE /sap/zproducts?id=1",
    "POST /sap/zproducts?id=1&action=restock&amount=10",
    "PUT /sap/zproducts?id=missing"
  ]);
  global.fetch = realFetch;
  server.close();
  console.log("ok  HTTP layer (URLs, verbs, error mapping match the ABAP handler)");
}

(async () => { await testMock(); await testHttp(); console.log("all tests passed"); })()
  .catch(e => { console.error(e); process.exit(1); });
