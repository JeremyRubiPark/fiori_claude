@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PA Employee - projection'
@Metadata.allowExtensions: true
define root view entity ZC_PA_Employee
  provider contract transactional_query
  as projection on ZR_PA_Employee
{
  key Pernr,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _PersAction : redirected to composition child ZC_PA_PersAction,
      _OrgAssign : redirected to composition child ZC_PA_OrgAssign,
      _PersData : redirected to composition child ZC_PA_PersData,
      _Address : redirected to composition child ZC_PA_Address
}
