# Organization Chart - Employee Central style Fiori prototype

Freestyle SAPUI5 app (sap.m Tree + sap.ui.layout Splitter) that shows an organization structure:

* left: unit tree with manager and headcount (incl. sub-units); search by unit name or ID (hits stay
  highlighted with their ancestors); expand / collapse all
* right: details of the selected unit (path, manager, validity, counts) and its employees,
  optionally including all sub-units
* key date: units and employees are filtered by validity, so you can see the past and future structure

All data is in-memory sample data (no SuccessFactors connection). See `docs/ec-integration.md`.

## Run

In SAP Business Application Studio (or Node 18+ locally):

```bash
npm install
npm start          # http://localhost:8080/index.html  (open the port from the PORTS tab in BAS)
npm test           # logic tests (Node) + static checks
```

## Try these scenarios

| Scenario | What to check |
|---|---|
| Today | 1 root, 4 departments; the closed "Legacy Sales Team" and the future "Overseas Sales Team" are hidden |
| Key date 2025-06-01 | "Legacy Sales Team" is back, with its lead who left in 2026 |
| Key date 2027-03-01 | "Overseas Sales Team" appears |
| Search `recruit` | only Recruiting Team and its parents remain, the hit is highlighted |
| Unit + "Include sub-units" | IT Department shows 2 direct employees, 7 with sub-units |

## Structure

```
webapp/model/OrgData.js    sample units and employees
webapp/model/OrgLogic.js   service layer (replace with SF OData calls)
webapp/view, controller    one page: tree + detail
webapp/i18n                English (default) and Korean
test/                      Node tests for OrgLogic and static checks
```

## Deploy

Same as the other apps: fill in `ui5-deploy.yaml` (or run **Fiori: Add Deployment Configuration** in BAS) and
`npm run deploy`. On a BTP ABAP Trial open the app by URL: `https://<abap-web-host>/sap/bc/ui5_ui5/sap/zec_orgchart/index.html`.

## Status

* `OrgLogic.js`: 16 automated tests pass. XML/JSON/JS syntax and i18n keys are checked by `test/static-check.js`.
* **The UI was not executed in the environment where it was written** (UI5 libraries could not be downloaded there).
  Expect to fix small runtime issues the first time you run `npm start`.
