# PA20 / PA30 style Employee Master Data - Fiori prototype

Freestyle SAPUI5 app (sap.m, sap.uxap ObjectPageLayout) that imitates the two HR transactions:

* **Display** (PA20): search employee, show infotype records valid at a key date or for all periods.
* **Maintain** (PA30): choose *Edit* (locks the employee), then **Create / Copy / Change / Delimit / Delete**
  records with the same time-constraint rules as SAP HR (TC1: no gaps/overlaps; TC2: per subtype).

Infotypes: 0000 Actions (display only), 0001 Organizational Assignment, 0002 Personal Data, 0006 Addresses.
All data is in-memory sample data - no ECC connection. See `docs/ecc-integration.md` for the path to ECC.

## Run

In SAP Business Application Studio (or local Node 18+):

```bash
npm install
npm start          # http://localhost:8080/index.html
npm test           # logic tests (Node) + static checks
```

Switch between display and maintain mode with the mode buttons on the search page, or start with
`index.html?mode=maintain` / a Launchpad tile parameter `mode=maintain`.
Reload the page to reset the sample data.

## Try these scenarios

| Scenario | Personnel no. | What to check |
|---|---|---|
| Normal history | 10000001 | Records for several periods; set key date 2021-03-01 |
| Locked by other user | 10000004 | Maintain mode -> Edit shows "locked by HRADMIN2" |
| Leaver | 10000005 | Status Withdrawn; last 0000 record |
| Future hire | 10000006 | Key date today: closest record is shown |
| TC1 insert | any | Create 0001 record with a begda in the middle of a period; previous record is delimited |
| TC2 addresses | 10000001 | Delimit, overlap error, different subtypes side by side |
| Delete TC1 | any | Previous record is stretched; last record cannot be deleted |

## Deploy to the ABAP environment (BTP Trial)

Same as the SuccessFactors app: run **Fiori: Add Deployment Configuration** in BAS (or fill in
`ui5-deploy.yaml`), then `npm run deploy`. Trial has no Launchpad role maintenance, so open the app by URL:
`https://<abap-web-host>/sap/bc/ui5_ui5/sap/zpa_hr/index.html`.

## Structure

```
webapp/model/infotypes.js   infotype metadata + sample code lists (data-driven UI)
webapp/model/PALogic.js     service layer (replace with OData V2 for ECC)
webapp/model/MockData.js    sample employees and records
webapp/view, controller     Search and Employee pages (sections/tables are generated from infotypes.js)
webapp/i18n                 English (default) and Korean
test/                       Node tests for PALogic and static checks
```

## Status

* `PALogic.js`: 35 automated tests pass.
* XML/JSON/JS syntax and i18n key coverage are checked by `test/static-check.js`.
* **The UI was not executed in the environment where it was written** (UI5 libraries could not be
  downloaded there). Expect to fix small runtime issues the first time you run `npm start`; report the
  console error and they are quick to fix.
