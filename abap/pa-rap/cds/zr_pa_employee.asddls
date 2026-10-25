@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PA Employee (BO root)'
define root view entity ZR_PA_Employee
  as select from zpa_emp
  composition [0..*] of ZR_PA_PersAction  as _PersAction
  composition [0..*] of ZR_PA_OrgAssign   as _OrgAssign
  composition [0..*] of ZR_PA_PersData    as _PersData
  composition [0..*] of ZR_PA_Address     as _Address
{
  key pernr                 as Pernr,
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

      /* compositions: one per infotype */
      _PersAction,
      _OrgAssign,
      _PersData,
      _Address
}
