@EndUserText.label: 'SuccessFactors Employee'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SF_EMPLOYEE_QUERY'
@UI.headerInfo: {
  typeName: 'Employee',
  typeNamePlural: 'Employees',
  title: { type: #STANDARD, value: 'FullName' },
  description: { type: #STANDARD, value: 'JobTitle' }
}
define root custom entity ZI_SF_EMPLOYEE
{
      @UI.facet: [
        { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'General', position: 10 },
        { id: 'Org',     purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,     label: 'Organization', position: 20, targetQualifier: 'Org' }
      ]

      @UI.lineItem:       [{ position: 10, importance: #HIGH }]
      @UI.identification: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
      @EndUserText.label: 'User ID'
  key UserId     : abap.char(100);

      @UI.lineItem:       [{ position: 20, importance: #HIGH }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Name'
      FullName   : abap.char(200);

      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'First Name'
      FirstName  : abap.char(128);

      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Last Name'
      LastName   : abap.char(128);

      @UI.lineItem:       [{ position: 30, importance: #MEDIUM }]
      @UI.identification: [{ position: 50 }]
      @EndUserText.label: 'E-Mail'
      Email      : abap.char(256);

      @UI.lineItem:       [{ position: 40, importance: #HIGH }]
      @UI.fieldGroup:     [{ qualifier: 'Org', position: 10 }]
      @UI.selectionField: [{ position: 20 }]
      @EndUserText.label: 'Department'
      Department : abap.char(128);

      @UI.lineItem:       [{ position: 50, importance: #MEDIUM }]
      @UI.fieldGroup:     [{ qualifier: 'Org', position: 20 }]
      @EndUserText.label: 'Division'
      Division   : abap.char(128);

      @UI.lineItem:       [{ position: 60, importance: #HIGH }]
      @UI.fieldGroup:     [{ qualifier: 'Org', position: 30 }]
      @EndUserText.label: 'Job Title'
      JobTitle   : abap.char(128);

      @UI.lineItem:       [{ position: 70, importance: #LOW }]
      @UI.fieldGroup:     [{ qualifier: 'Org', position: 40 }]
      @EndUserText.label: 'Location'
      Location   : abap.char(128);

      @UI.lineItem:       [{ position: 80, importance: #LOW }]
      @UI.fieldGroup:     [{ qualifier: 'Org', position: 50 }]
      @EndUserText.label: 'Status'
      Status     : abap.char(32);
}
