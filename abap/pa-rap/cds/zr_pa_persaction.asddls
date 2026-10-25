@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PA Personnel Action (0000)'
define view entity ZR_PA_PersAction
  as select from zpa_it0000
  association to parent ZR_PA_Employee as _Employee on $projection.Pernr = _Employee.Pernr
{
  key record_uuid           as RecordUuid,
      pernr                 as Pernr,
      begda                 as Begda,
      endda                 as Endda,
      massn                 as Massn,
      massg                 as Massg,
      stat2                 as Stat2,
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
