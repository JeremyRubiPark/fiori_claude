# Connecting the app to SAP ECC

The prototype runs on in-memory sample data. All data access goes through
`webapp/model/PALogic.js`; controllers and views never touch storage. To go live,
re-implement the functions of that module on an OData V2 service served by your ECC
Gateway and keep the function signatures.

> Status: the object names below are a **proposal**. None of this was run against an
> ECC system (no access was available). Verify FM/BAPI names, parameters and
> customizing tables in your release before implementing.

## 1. Architecture

```
Browser (this app)  --HTTPS-->  BTP Destination (Cloud Connector)  -->  ECC Gateway (SEGW, OData V2)
                                                                        -->  HR function modules / BAPIs
```

* ECC is on-premise: expose it through **Cloud Connector** + a BTP **Destination** with
  principal propagation (recommended), so ECC authorizations (P_ORGIN, P_ORGINCON,
  P_PERNR) apply to the real user.
* Do **not** connect with a technical user that has broad HR rights.

## 2. Suggested OData V2 model (SEGW project `ZHR_PA`)

| Entity set | Key | Purpose | Maps to PALogic |
|---|---|---|---|
| `EmployeeSet` | Pernr, KeyDate | search + header | `searchEmployees`, `getEmployee` |
| `InfotypeRecordSet` | Pernr, Infty, Subty, Objps, Sprps, Endda, Begda, Seqnr | one row per infotype record; generic field bag or typed entities per infotype | `getRecords`, `getRecord`, `create`, `change`, `delimit`, `remove` |
| `ActionSet` (function import `ExecuteAction`) | Massn, Pernr, Begda, Massg + infotype payloads | atomic personnel action; one call, one commit/rollback | `executeAction`, `actionDefaults` |
| `LockSet` | Pernr | enqueue / dequeue | `lock`, `unlock`, `getLock` |
| `ValueHelp*Set` | Key, Text | customizing value helps | `infotypes.js` LISTS |

Typed entities per infotype (`Infotype0001`, `Infotype0002`, ...) are easier to
secure and validate than a generic field bag.

## 3. Backend building blocks to evaluate (verify in your system)

| Need | Candidate | Note |
|---|---|---|
| Read infotype | `HR_READ_INFOTYPE` | honors authorization via `P_PERNR` check inside? Verify; use `HR_CHECK_AUTHORITY_INFTY` explicitly |
| Enqueue employee | `HR_EMPLOYEE_ENQUEUE` / `BAPI_EMPLOYEE_ENQUEUE` | dequeue with the matching DEQUEUE function |
| Insert / change / delimit / delete | `HR_INFOTYPE_OPERATION` | operations INS, MOD, DEL, COP, LIS9; it applies the time-constraint logic of PA30. The mock in `PALogic.js` imitates this behaviour |
| Personnel action (0000/0302) | PA40 logic, `HR_MAINTAIN_MASTERDATA` | infotype 0000 is read-only in the PA30 part of the prototype; actions run through `executeAction`. In ECC the action type determines the info group (T588D/T588Z, feature MNMAC, T529A/T529T, T530); the prototype hard-codes three actions in `infotypes.js` (`ACTIONS`) |
| New personnel number | number range object `PREL` (`NUMBER_GET_NEXT`) or `HR_MAINTAIN_MASTERDATA` with an empty PERNR | the prototype takes max+1 |
| Value helps | tables T529A/T530 (actions/reasons), T500P/T001P (areas), T503K (employee subgroup), T005 (countries), T591A (subtypes) | read through RFC or CDS-like Gateway read |

## 4. What to replace in the app

1. `model/PALogic.js`: each function becomes an `ODataModel` (V2) call. Return the same
   shapes (`{ok, errors:[{code,params}]}`); map ECC messages (BAPIRET2 / `/IWBEP/CX_MGW_BUSI_EXCEPTION`)
   to the existing codes or add new `msg_*` keys in both i18n files. Functions become asynchronous
   (Promises); in the controllers replace direct calls with `.then(...)` - `_refresh`, the dialogs'
   save handlers and `onToggleEdit` are the only call sites.
2. `model/infotypes.js`: remove the `LISTS` sample values and load value helps from the service
   (keep the `fields` metadata or derive it from `$metadata`).
3. `model/MockData.js`: no longer needed.
4. Add the service to `manifest.json` (`sap.app.dataSources`) and the destination to `xs-app.json`/`ui5.yaml`.

## 5. Security and compliance checklist

* HR data is personal data: apply least privilege, log changes (ECC infotype change logging / report RPUAUD00).
* Maintain a separate role for display (PA20) and maintain (PA30): S_TCODE is not enough for Gateway, so check
  `P_ORGIN` (AUTHC = R/W) in the backend implementation.
* Keep sample data out of production images.
* Test with real-world date-effective histories (gaps in TC2 infotypes, future-dated records, leavers, re-hires).

## 6. Known simplifications in the prototype

* Infotype 0000 is display only in PA30; the PA40 part supports three actions only, without action/reason dependency (T530) and without the status-dependent info group variants (feature MNMAC / T588Z dynamic actions).
* No authorization objects except "0000 not maintainable"; no country-specific screens (MOLGA).
* Only one fixed user (`DEMO_USER`) and a simulated lock by another user on personnel number 10000004.
* No "lock release" UI and no change documents/history beyond "changed on / by".
