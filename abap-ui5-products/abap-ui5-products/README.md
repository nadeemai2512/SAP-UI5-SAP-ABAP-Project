# abap-ui5-products - SAP ABAP backend + SAPUI5 frontend

A Product Manager: an **ABAP REST/JSON service** (ICF handler class + database table) and a
**SAPUI5 app** (list, search, add, edit, delete, restock) that talks to it.

```
abap-ui5-products/
├── abap/                       ABAP code in abapGit format
│   ├── .abapgit.xml
│   ├── abaplint.json
│   └── src/
│       ├── zproduct.tabl.xml               table ZPRODUCT
│       ├── zcl_product_http.clas.abap      ICF handler (REST service) + validation
│       ├── zcl_product_http.clas.testclasses.abap   ABAP Unit tests
│       ├── zcl_product_http.clas.xml
│       ├── zproduct_seed.prog.abap         report that loads 5 sample products
│       └── zproduct_seed.prog.xml
└── ui5/                        SAPUI5 app (UI5 Tooling project)
    ├── webapp/                 Component, manifest, view, controller, fragment, i18n, model/ProductService.js
    ├── tests/service.test.js   Node tests for the service layer
    ├── ui5.yaml                dev server + proxy to your ABAP system
    └── package.json
```

## What was verified
- ABAP: syntax-checked with **abaplint** (0 issues; the standard SAP HTTP interfaces were stubbed for the
  linter because abaplint does not know SAP standard objects). It has **not been executed on a live SAP
  system** - I had no ABAP system available. Follow the checklist in section 1 on your system.
- UI5: `npm test` (service layer incl. HTTP contract against a fake server), `ui5 build`, `ui5 serve` and the dev
  proxy were run. The UI screens themselves load UI5 from the internet, so open them once to confirm.

Requirements: ABAP 7.50+ (on-premise / S/4HANA / ABAP Platform; uses `/UI2/CL_JSON`, which is in standard
SAP_UI), Node.js 18+ for UI5.

---

## 1. ABAP backend (5 steps)

1. **Import the code** with [abapGit](https://abapgit.org): create an *offline* repository from the `abap/` folder
   (zip it, or push it to Git), package e.g. `$ZPRODUCTS`, then *Pull*. This creates table `ZPRODUCT`,
   class `ZCL_PRODUCT_HTTP`, report `ZPRODUCT_SEED`.
   *No abapGit?* Create the objects by hand:
   - **SE11** - transparent table `ZPRODUCT`, delivery class A, fields:

     | Field | Key | Type | Length / decimals |
     |---|---|---|---|
     | MANDT | X | CLNT | 3 |
     | PRODUCT_ID | X | CHAR | 32 |
     | NAME |  | CHAR | 100 |
     | DESCRIPTION |  | CHAR | 255 |
     | CATEGORY |  | CHAR | 40 |
     | PRICE |  | DEC | 11 / 2 |
     | CURRENCY |  | CHAR | 3 |
     | STOCK |  | INT4 | 10 |

     Technical settings: data class APPL0, size category 0. Activate.
   - **SE24** - class `ZCL_PRODUCT_HTTP`: paste `zcl_product_http.clas.abap` (in SE80/ADT use the source-based
     editor); test classes go to *Goto -> Local Test Classes*. Activate.
   - **SE38** - program `ZPRODUCT_SEED`: paste `zproduct_seed.prog.abap`, activate.
2. **Run `ZPRODUCT_SEED`** (SE38, F8) to insert five sample products. Safe to run twice (it skips if data exists).
3. **Run the unit tests**: SE24 -> class -> *Class -> Unit Test* (or ADT: Ctrl+Shift+F10). 4 tests, all should pass.
4. **Create the HTTP service** in **SICF** (`/sap/zproducts`):
   - SICF -> hierarchy `DEFAULT_HOST` -> `sap` -> right click -> *New Sub-Element*, name **`zproducts`**, type
     *Standard service* (Service Name `zproducts`).
   - Tab *Logon Data*: keep *Required* (users must log in) - or set a service user for tests only.
   - Tab *Handler List*: add `ZCL_PRODUCT_HTTP`. Save, then right click the node -> *Activate Service*.
5. **Test it** (replace host/port/credentials):
   ```
   curl -u USER:PASS http://HOST:PORT/sap/zproducts
   curl -u USER:PASS -X POST -H "Content-Type: application/json" \
        -d '{"name":"Webcam","category":"Accessories","price":49.9,"currency":"EUR","stock":12}' \
        http://HOST:PORT/sap/zproducts
   ```
   Add `?sap-client=100` if you need a specific client. Expect JSON such as
   `[{"productId":"…","name":"Laptop Pro 15","price":1499.00,"currency":"EUR","stock":25, …}]`.

### REST contract
| Verb | URL | Description |
|---|---|---|
| GET | `/sap/zproducts` | list (sorted by name) |
| GET | `/sap/zproducts?id=<id>` | one product (404 if missing) |
| POST | `/sap/zproducts` | create, returns 201 + product |
| PUT | `/sap/zproducts?id=<id>` | update |
| DELETE | `/sap/zproducts?id=<id>` | delete, returns 204 |
| POST | `/sap/zproducts?id=<id>&action=restock&amount=10` | increase stock |

Validation errors return HTTP 400 and `{"error":"…"}` (name required, price/stock not negative).

> Security note: this is a demo service. For production add authorization checks (AUTHORITY-CHECK) in the
> handler and CSRF protection, and restrict the SICF service to the right users.

---

## 2. SAPUI5 frontend

### a) Try it immediately - demo mode (no ABAP needed)
```
cd ui5
npm install
npm run start:mock        # opens http://localhost:8080/index.html?mock=true
npm test                  # service-layer tests
```
Demo mode uses an in-memory store with the same contract as the ABAP service.

### b) Develop against your ABAP system
Edit `baseUri` in `ui5/ui5.yaml` (or set `UI5_MIDDLEWARE_SIMPLE_PROXY_BASEURI`,
`UI5_MIDDLEWARE_SIMPLE_PROXY_USERNAME`, `UI5_MIDDLEWARE_SIMPLE_PROXY_PASSWORD`), then:
```
npm start                 # http://localhost:8080/index.html  -> /sap/zproducts is proxied to ABAP
```

### c) Deploy the UI5 app onto the ABAP system (BSP / SAPUI5 repository)
```
npm run build             # creates ui5/dist
```
In the ABAP system run report **`/UI5/UI5_REPOSITORY_LOAD`** (SE38): choose *Upload*, name `ZPRODUCTS_UI5`,
package of your choice, and select the `dist` folder. Then open
`http://HOST:PORT/sap/bc/ui5_ui5/sap/zproducts_ui5/index.html`.
When served from ABAP the app automatically uses the system's own UI5 libraries and the relative service
`/sap/zproducts` (same origin, so no CORS or proxy is needed).
