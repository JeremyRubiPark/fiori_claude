@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PA Organizational Assignment (0001)'
define view entity ZR_PA_OrgAssign
  as select from zpa_it0001
  association to parent ZR_PA_Employee as _Employee on $projection.Pernr = _Employee.Pernr
{
  key record_uuid           as RecordUuid,
      pernr                 as Pernr,
      begda                 as Begda,
      endda                 as Endda,
      bukrs                 as Bukrs,
      werks                 as Werks,
      btrtl                 as Btrtl,
      persg                 as Persg,
      persk                 as Persk,
      orgeh                 as Orgeh,
      plans                 as Plans,
      stell                 as Stell,
      kostl                 as Kostl,
      abkrs                 as Abkrs,
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
