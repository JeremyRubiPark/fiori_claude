# Connecting the org chart to SuccessFactors Employee Central

The prototype runs on sample data. All data access goes through `webapp/model/OrgLogic.js`
(`getTree`, `getUnit`, `getMembers`). To go live, re-implement these three functions on the
SuccessFactors OData API and keep their return shapes; views and controllers stay unchanged.

> Status: nothing here was run against a SuccessFactors tenant (none was available). Entity and field
> names below are **candidates from general knowledge of Employee Central**; confirm every name in your tenant's
> *API Center > OData API Data Dictionary* before implementing. Field availability depends on the tenant configuration.

## 1. Connection

```
Browser (this app) -> BTP Destination -> SuccessFactors OData API (V2)  https://<api-host>/odata/v2/
```

* Create a BTP **Destination** to the tenant's API server (OAuth 2.0 SAML bearer with the logged-in user is the usual
  choice so that SF role-based permissions apply; Basic auth is only suitable for tests).
* In SF, the integrating user/OAuth client needs read permission for the entities below (Admin Center
  *Manage Permission Roles* / *Manage OAuth2 Client Applications*).
* Do not use a technical user with broad HR rights: an org chart exposes employee names and positions.

## 2. Where the data lives (candidates)

| App concept | Candidate in EC | Note |
|---|---|---|
| Organizational unit | Foundation Objects `FODepartment`, `FODivision`, `FOBusinessUnit` (or `Position`-based structure) | Foundation Objects are effective-dated; a parent reference builds the hierarchy. Which FO type forms the tree differs per customer |
| Unit manager | a head-of-unit style field on the FO, or the `EmpJob` manager of the unit members | depends on the customer model |
| Employee + unit assignment | `EmpJob` (user id, department, job title, start/end date, manager) | effective-dated; use the record valid at the key date |
| Employee name | `PerPersonal` / `User` | name of the current record |
| Position-based org chart | `Position` with parent position | only when Position Management is used |

SuccessFactors also ships its own *Org Chart* UI. Build this app only if you need a custom view, other
data sources in the same UI, or a different interaction than the standard one.

## 3. What to replace in the app

1. `getTree(keyDate, query)`: read the units valid at the key date (effective-dated read, e.g. with the `asOfDate`
   parameter that EC supports for effective-dated entities - verify in the API documentation), build the hierarchy on
   the client (or server-side in a BTP CAP/ABAP layer), add manager name and headcounts, and apply the search filter.
2. `getUnit(id, keyDate)`: one unit with its parent chain and counts.
3. `getMembers(id, keyDate, includeSub)`: read `EmpJob` for the unit (and sub-unit ids) valid at the key date.
4. Make the functions asynchronous (Promises) and adapt the four call sites in `controller/OrgChart.controller.js`
   (`_loadTree`, `onSelect`, `_loadMembers`, and the initial load).
5. For large organizations (thousands of units) do not build the whole tree in the browser: load children lazily on expand
   (sap.m.Tree supports this with the `toggleOpenState` event) and page the member list (`$top` / `$skip`, server-driven paging).

## 4. Security and privacy checklist

* Respect SF permissions by using a propagated user; do not cache employee data in shared storage.
* Decide whether contact data, birth dates or salary must never reach the client (this prototype shows none of them).
* Keep the sample data out of production builds.

## 5. Known simplifications in the prototype

* One fixed unit hierarchy type; no matrix or dotted-line relations; one manager per unit.
* Employees have exactly one unit; no concurrent employment or global assignments.
* No photo, no contact card, no export; read-only.
