@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Personnel Action - projection'
@Metadata.allowExtensions: true
define view entity ZC_PA_PersAction
  as projection on ZR_PA_PersAction
{
  key RecordUuid,
      Pernr,
      Begda,
      Endda,
      Massn,
      Massg,
      Stat2,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Employee : redirected to parent ZC_PA_Employee
}
