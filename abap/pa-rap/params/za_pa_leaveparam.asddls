@EndUserText.label: 'PA40 Leaving - parameters'
define root abstract entity ZA_PA_LeaveParam
{
  @EndUserText.label: 'Start Date of Action'
  Begda    : abap.dats;
  @EndUserText.label: 'Reason for Action'
  Massg    : abap.char(2);
}
