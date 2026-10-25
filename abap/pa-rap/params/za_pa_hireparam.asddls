@EndUserText.label: 'PA40 Hiring - parameters'
define root abstract entity ZA_PA_HireParam
{
  @EndUserText.label: 'Start Date of Action'
  Begda    : abap.dats;
  @EndUserText.label: 'Reason for Action'
  Massg    : abap.char(2);
  // infotype 0002
  @EndUserText.label: 'Form of Address'
  Anred    : abap.char(1);
  @EndUserText.label: 'Last Name'
  Nachn    : abap.char(40);
  @EndUserText.label: 'First Name'
  Vorna    : abap.char(40);
  @EndUserText.label: 'Date of Birth'
  Gbdat    : abap.dats;
  @EndUserText.label: 'Gender'
  Gesch    : abap.char(1);
  @EndUserText.label: 'Nationality'
  Natio    : abap.char(3);
  @EndUserText.label: 'Language'
  Sprsl    : abap.lang;
  @EndUserText.label: 'Marital Status'
  Famst    : abap.char(1);
  @EndUserText.label: 'Number of Children'
  Anzkd    : abap.int1;
  // infotype 0001
  @EndUserText.label: 'Company Code'
  Bukrs    : abap.char(4);
  @EndUserText.label: 'Personnel Area'
  Werks    : abap.char(4);
  @EndUserText.label: 'Personnel Subarea'
  Btrtl    : abap.char(4);
  @EndUserText.label: 'Employee Group'
  Persg    : abap.char(1);
  @EndUserText.label: 'Employee Subgroup'
  Persk    : abap.char(2);
  @EndUserText.label: 'Organizational Unit'
  Orgeh    : abap.numc(8);
  @EndUserText.label: 'Position'
  Plans    : abap.numc(8);
  @EndUserText.label: 'Job'
  Stell    : abap.numc(8);
  @EndUserText.label: 'Cost Center'
  Kostl    : abap.char(10);
  @EndUserText.label: 'Payroll Area'
  Abkrs    : abap.char(2);
  // infotype 0006
  @EndUserText.label: 'Street'
  Stras    : abap.char(60);
  @EndUserText.label: 'City'
  Ort01    : abap.char(40);
  @EndUserText.label: 'Postal Code'
  Pstlz    : abap.char(10);
  @EndUserText.label: 'Country'
  Land1    : abap.char(3);
  @EndUserText.label: 'Telephone'
  Telnr    : abap.char(20);
}
