@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Address - projection'
@Metadata.allowExtensions: true
define view entity ZC_PA_Address
  as projection on ZR_PA_Address
{
  key RecordUuid,
      Pernr,
      Subty,
      Begda,
      Endda,
      Stras,
      Ort01,
      Pstlz,
      Land1,
      Telnr,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Employee : redirected to parent ZC_PA_Employee
}
