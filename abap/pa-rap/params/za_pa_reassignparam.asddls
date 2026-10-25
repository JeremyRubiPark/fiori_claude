@EndUserText.label: 'PA40 Org. Reassignment - parameters'
define root abstract entity ZA_PA_ReassignParam
{
  @EndUserText.label: 'Start Date of Action'
  Begda    : abap.dats;
  @EndUserText.label: 'Reason for Action'
  Massg    : abap.char(2);
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
}
