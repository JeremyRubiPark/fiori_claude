@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PA Address (0006)'
define view entity ZR_PA_Address
  as select from zpa_it0006
  association to parent ZR_PA_Employee as _Employee on $projection.Pernr = _Employee.Pernr
{
  key record_uuid           as RecordUuid,
      pernr                 as Pernr,
      subty                 as Subty,
      begda                 as Begda,
      endda                 as Endda,
      stras                 as Stras,
      ort01                 as Ort01,
      pstlz                 as Pstlz,
      land1                 as Land1,
      telnr                 as Telnr,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Employee
}
