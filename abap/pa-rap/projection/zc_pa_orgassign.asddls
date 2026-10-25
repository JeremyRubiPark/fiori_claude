@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Organizational Assignment - projection'
@Metadata.allowExtensions: true
define view entity ZC_PA_OrgAssign
  as projection on ZR_PA_OrgAssign
{
  key RecordUuid,
      Pernr,
      Begda,
      Endda,
      Bukrs,
      Werks,
      Btrtl,
      Persg,
      Persk,
      Orgeh,
      Plans,
      Stell,
      Kostl,
      Abkrs,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Employee : redirected to parent ZC_PA_Employee
}
