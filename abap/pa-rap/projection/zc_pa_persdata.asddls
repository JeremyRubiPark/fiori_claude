@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Personal Data - projection'
@Metadata.allowExtensions: true
define view entity ZC_PA_PersData
  as projection on ZR_PA_PersData
{
  key RecordUuid,
      Pernr,
      Begda,
      Endda,
      Anred,
      Nachn,
      Vorna,
      Gbdat,
      Gesch,
      Natio,
      Sprsl,
      Famst,
      Anzkd,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Employee : redirected to parent ZC_PA_Employee
}
