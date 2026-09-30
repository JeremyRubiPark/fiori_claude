sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zsfemployee/test/integration/pages/EmployeeList.gen",
	"zsfemployee/test/integration/pages/EmployeeObjectPage.gen"
], function (JourneyRunner, EmployeeListGenerated, EmployeeObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zsfemployee') + '/test/flp.html#app-preview',
        pages: {
			onTheEmployeeListGenerated: EmployeeListGenerated,
			onTheEmployeeObjectPageGenerated: EmployeeObjectPageGenerated
        },
        async: true
    });

    return runner;
});

