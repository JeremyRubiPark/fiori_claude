"! @testing BDEF:ZR_PA_EMPLOYEE
CLASS ztc_pa_employee DEFINITION
  PUBLIC FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS c_forever TYPE d VALUE '99991231'.

    TYPES tt_actions TYPE TABLE FOR READ RESULT zr_pa_employee\\Employee\_PersAction.
    TYPES tt_org     TYPE TABLE FOR READ RESULT zr_pa_employee\\Employee\_OrgAssign.
    TYPES tt_pers    TYPE TABLE FOR READ RESULT zr_pa_employee\\Employee\_PersData.
    TYPES tt_addr    TYPE TABLE FOR READ RESULT zr_pa_employee\\Employee\_Address.

    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS set_authorization
      IMPORTING actvt TYPE zpa_auth-actvt.
    METHODS hire
      IMPORTING begda        TYPE d DEFAULT '20200101'
      RETURNING VALUE(pernr) TYPE zr_pa_employee-Pernr.
    METHODS add_orgassign
      IMPORTING pernr TYPE zr_pa_employee-Pernr
                begda TYPE d
                endda TYPE d OPTIONAL
                orgeh TYPE zr_pa_orgassign-Orgeh DEFAULT '20000002'.
    METHODS add_address
      IMPORTING pernr TYPE zr_pa_employee-Pernr
                subty TYPE zr_pa_address-Subty
                begda TYPE d.
    METHODS prepare_fails
      IMPORTING pernr         TYPE zr_pa_employee-Pernr
      RETURNING VALUE(failed) TYPE abap_bool.
    METHODS activate_fails
      IMPORTING pernr         TYPE zr_pa_employee-Pernr
      RETURNING VALUE(failed) TYPE abap_bool.
    METHODS read_actions IMPORTING pernr TYPE zr_pa_employee-Pernr RETURNING VALUE(result) TYPE tt_actions.
    METHODS read_org     IMPORTING pernr TYPE zr_pa_employee-Pernr RETURNING VALUE(result) TYPE tt_org.
    METHODS read_pers    IMPORTING pernr TYPE zr_pa_employee-Pernr RETURNING VALUE(result) TYPE tt_pers.
    METHODS read_addr    IMPORTING pernr TYPE zr_pa_employee-Pernr RETURNING VALUE(result) TYPE tt_addr.

    METHODS hire_creates_info_group     FOR TESTING.
    METHODS hire_missing_field_rejected FOR TESTING.
    METHODS tc1_new_delimits_previous   FOR TESTING.
    METHODS tc1_earlier_end_splits      FOR TESTING.
    METHODS tc1_end_beyond_is_adjusted  FOR TESTING.
    METHODS tc1_same_start_rejected     FOR TESTING.
    METHODS tc1_remove_last_stretches   FOR TESTING.
    METHODS tc1_remove_first_moves_next FOR TESTING.
    METHODS tc1_only_record_kept        FOR TESTING.
    METHODS tc1_persdata_delimits       FOR TESTING.
    METHODS tc2_same_type_delimits      FOR TESTING.
    METHODS tc2_other_type_independent  FOR TESTING.
    METHODS tc2_same_start_rejected     FOR TESTING.
    METHODS tc2_delimit_moves_end       FOR TESTING.
    METHODS tc2_delimit_outside_rejected FOR TESTING.
    METHODS reassign_writes_0000_0001   FOR TESTING.
    METHODS leave_sets_withdrawn        FOR TESTING.
    METHODS action_on_leaver_rejected   FOR TESTING.
    METHODS same_day_action_rejected    FOR TESTING.
    METHODS action_before_hire_rejected FOR TESTING.
    METHODS display_user_cannot_hire    FOR TESTING.
ENDCLASS.


CLASS ztc_pa_employee IMPLEMENTATION.

  METHOD class_setup.
    " ABAP Unit tests for the PA RAP business object
    " Ports the business-rule scenarios of pa-fiori/test/palogic.test.js to EML.
    " 
    " How the tests run
    " - All PA tables (active + draft) are replaced by test doubles (CL_OSQL_TEST_ENVIRONMENT),
    " so the tests never see or change real data. Personnel numbers start at 10000001.
    " - Every test works on a DRAFT created by the Hire action and calls the draft action
    " Prepare, which runs the on-save determinations and validations (like the Save button).
    " - Nothing is committed: TEARDOWN rolls back the transactional buffer.
    " - The EML calls are NOT in local mode, so feature control (disabled buttons) is checked too.

    sql_env = cl_osql_test_environment=>create(
                i_dependency_list = VALUE #( ( 'ZPA_EMP' )    ( 'ZPA_EMP_D' )
                                             ( 'ZPA_IT0000' ) ( 'ZPA_IT0000_D' )
                                             ( 'ZPA_IT0001' ) ( 'ZPA_IT0001_D' )
                                             ( 'ZPA_IT0002' ) ( 'ZPA_IT0002_D' )
                                             ( 'ZPA_IT0006' ) ( 'ZPA_IT0006_D' )
                                             ( 'ZPA_AUTH' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_env->clear_doubles( ).
    " default: the test user may maintain every personnel area
    set_authorization( '02' ).
  ENDMETHOD.

  METHOD set_authorization.
    DATA auth TYPE STANDARD TABLE OF zpa_auth WITH EMPTY KEY.
    sql_env->clear_doubles( ).
    auth = VALUE #( ( uname = cl_abap_context_info=>get_user_technical_name( )
                      werks = '*'
                      actvt = actvt ) ).
    sql_env->insert_test_data( auth ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD hire.
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Hire FROM VALUE #( ( %cid   = 'HIRE'
                                     %param = VALUE #( Begda = begda
                                                       Massg = '01'
                                                       Nachn = 'Test'
                                                       Vorna = 'Employee'
                                                       Gbdat = '19900101'
                                                       Gesch = '1'
                                                       Bukrs = '1000'
                                                       Werks = '1000'
                                                       Btrtl = '0001'
                                                       Persg = '1'
                                                       Persk = 'K1'
                                                       Orgeh = '20000001'
                                                       Plans = '30000001'
                                                       Abkrs = 'K1'
                                                       Stras = 'Street 1'
                                                       Ort01 = 'Seoul'
                                                       Land1 = 'KR' ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Hire failed in a helper' ).
    pernr = mapped-employee[ 1 ]-Pernr.
  ENDMETHOD.

  METHOD add_orgassign.
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        CREATE BY \_OrgAssign
        FIELDS ( Begda Endda Bukrs Werks Btrtl Persg Persk Orgeh Plans Abkrs )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                        Pernr     = pernr
                        %target   = VALUE #( ( %cid      = |ORG{ begda }|
                                               %is_draft = if_abap_behv=>mk-on
                                               Begda     = begda
                                               Endda     = endda
                                               Bukrs     = '1000'
                                               Werks     = '1000'
                                               Btrtl     = '0001'
                                               Persg     = '1'
                                               Persk     = 'K1'
                                               Orgeh     = orgeh
                                               Plans     = '30000002'
                                               Abkrs     = 'K1' ) ) ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = '0001 create failed in a helper' ).
  ENDMETHOD.

  METHOD add_address.
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        CREATE BY \_Address
        FIELDS ( Subty Begda Stras Ort01 Land1 )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                        Pernr     = pernr
                        %target   = VALUE #( ( %cid      = |ADR{ subty }{ begda }|
                                               %is_draft = if_abap_behv=>mk-on
                                               Subty     = subty
                                               Begda     = begda
                                               Stras     = 'Street 2'
                                               Ort01     = 'Busan'
                                               Land1     = 'KR' ) ) ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = '0006 create failed in a helper' ).
  ENDMETHOD.

  METHOD prepare_fails.
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Prepare FROM VALUE #( ( %key-Pernr = pernr ) )
      FAILED DATA(response).
    failed = xsdbool( response IS NOT INITIAL ).
  ENDMETHOD.

  METHOD activate_fails.
    " Same path as the Save button: Activate runs Prepare (determinations + validations)
    " and copies the draft to the active instance only if nothing failed.
    " Used for the rejection tests; nothing is committed, TEARDOWN rolls back.
    " Activate creates the active instance, so it needs a %cid (RAP contract MISSING_CID).
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Activate FROM VALUE #( ( %cid = 'ACTIVATE'  %key-Pernr = pernr ) )
      FAILED DATA(response).
    failed = xsdbool( response IS NOT INITIAL ).
  ENDMETHOD.

  METHOD read_actions.
    READ ENTITIES OF zr_pa_employee
      ENTITY Employee BY \_PersAction
        ALL FIELDS WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on  Pernr = pernr ) )
      RESULT result.
    SORT result BY Begda.
  ENDMETHOD.

  METHOD read_org.
    READ ENTITIES OF zr_pa_employee
      ENTITY Employee BY \_OrgAssign
        ALL FIELDS WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on  Pernr = pernr ) )
      RESULT result.
    SORT result BY Begda.
  ENDMETHOD.

  METHOD read_pers.
    READ ENTITIES OF zr_pa_employee
      ENTITY Employee BY \_PersData
        ALL FIELDS WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on  Pernr = pernr ) )
      RESULT result.
    SORT result BY Begda.
  ENDMETHOD.

  METHOD read_addr.
    READ ENTITIES OF zr_pa_employee
      ENTITY Employee BY \_Address
        ALL FIELDS WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on  Pernr = pernr ) )
      RESULT result.
    SORT result BY Subty Begda.
  ENDMETHOD.

  METHOD hire_creates_info_group.
    " prototype: "hiring creates a new employee with all infotypes"
    DATA(pernr) = hire( '20261101' ).

    cl_abap_unit_assert=>assert_equals( act = pernr exp = '10000001' ).

    DATA(actions) = read_actions( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( actions ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Massn exp = '01' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Stat2 exp = '3' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Begda exp = '20261101' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Endda exp = c_forever ).

    cl_abap_unit_assert=>assert_equals( act = lines( read_org( pernr ) )  exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( read_pers( pernr ) ) exp = 1 ).
    DATA(addr) = read_addr( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( addr ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Subty exp = '1' ).

    cl_abap_unit_assert=>assert_false( act = prepare_fails( pernr ) msg = 'Hired employee must be consistent' ).
  ENDMETHOD.

  METHOD hire_missing_field_rejected.
    " prototype: "hiring is atomic: invalid step saves nothing"
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Hire FROM VALUE #( ( %cid   = 'HIRE'
                                     %param = VALUE #( Begda = '20261101'
                                                       Vorna = 'No last name' ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-employee ).
    cl_abap_unit_assert=>assert_initial( act = mapped-employee msg = 'No employee may be created' ).
  ENDMETHOD.

  METHOD tc1_new_delimits_previous.
    " prototype: "new record delimits the valid one and runs to 9999-12-31"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20230701' ).

    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).
    DATA(org) = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Endda exp = '20230630' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Begda exp = '20230701' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD tc1_earlier_end_splits.
    " prototype: "earlier end date splits the old record (rest is kept)"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20210101' endda = '20211231' orgeh = '20000003' ).

    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).
    DATA(org) = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 3 ).
    " 2020-01-01 .. 2020-12-31  old values
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Endda exp = '20201231' ).
    " 2021-01-01 .. 2021-12-31  new values
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Orgeh exp = '20000003' ).
    " 2022-01-01 .. 9999-12-31  old values come back
    cl_abap_unit_assert=>assert_equals( act = org[ 3 ]-Begda exp = '20220101' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 3 ]-Endda exp = c_forever ).
    cl_abap_unit_assert=>assert_equals( act = org[ 3 ]-Orgeh exp = org[ 1 ]-Orgeh ).
  ENDMETHOD.

  METHOD tc1_end_beyond_is_adjusted.
    " prototype: "end date beyond the covering record is adjusted"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20230701' ).
    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).

    " covers 2020-01-01 .. 2023-06-30, asks to run until 2024-12-31
    add_orgassign( pernr = pernr begda = '20210101' endda = '20241231' ).
    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).

    DATA(org) = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Begda exp = '20210101' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Endda exp = '20230630' ).
  ENDMETHOD.

  METHOD tc1_same_start_rejected.
    " prototype: "same start date -> error"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20200101' ).

    cl_abap_unit_assert=>assert_true( act = activate_fails( pernr ) msg = 'Same start date must be rejected' ).
  ENDMETHOD.

  METHOD tc1_remove_last_stretches.
    " prototype: "TC1: deleting a middle/last record extends the previous one"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20230701' ).
    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).

    DATA(org) = read_org( pernr ).
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY OrgAssign
        EXECUTE RemoveRecord FROM VALUE #( ( %tky = org[ 2 ]-%tky ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).

    org = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Begda exp = '20200101' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD tc1_remove_first_moves_next.
    " prototype: "TC1: deleting the first record moves the next start back"
    DATA(pernr) = hire( '20200101' ).
    add_orgassign( pernr = pernr begda = '20230701' ).
    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).

    DATA(org) = read_org( pernr ).
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY OrgAssign
        EXECUTE RemoveRecord FROM VALUE #( ( %tky = org[ 1 ]-%tky ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).

    org = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Begda exp = '20200101' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Orgeh exp = '20000002' ).
  ENDMETHOD.

  METHOD tc1_only_record_kept.
    " prototype: "TC1: the last remaining record cannot be deleted"
    DATA(pernr) = hire( '20200101' ).
    DATA(org) = read_org( pernr ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY OrgAssign
        EXECUTE RemoveRecord FROM VALUE #( ( %tky = org[ 1 ]-%tky ) )
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-orgassign ).
    cl_abap_unit_assert=>assert_equals( act = lines( read_org( pernr ) ) exp = 1 ).
  ENDMETHOD.

  METHOD tc1_persdata_delimits.
    " 0002 has the same time constraint as 0001
    DATA(pernr) = hire( '20200101' ).
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        CREATE BY \_PersData
        FIELDS ( Begda Nachn Vorna Gbdat Gesch )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                        Pernr     = pernr
                        %target   = VALUE #( ( %cid      = 'PERS1'
                                               %is_draft = if_abap_behv=>mk-on
                                               Begda     = '20240101'
                                               Nachn     = 'Married'
                                               Vorna     = 'Employee'
                                               Gbdat     = '19900101'
                                               Gesch     = '1' ) ) ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).

    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).
    DATA(pers) = read_pers( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( pers ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = pers[ 1 ]-Endda exp = '20231231' ).
    cl_abap_unit_assert=>assert_equals( act = pers[ 2 ]-Nachn exp = 'Married' ).
  ENDMETHOD.

  METHOD tc2_same_type_delimits.
    " prototype: "new address of the same subtype delimits the valid one"
    DATA(pernr) = hire( '20200101' ).
    add_address( pernr = pernr subty = '1' begda = '20230101' ).

    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).
    DATA(addr) = read_addr( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( addr ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Endda exp = '20221231' ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 2 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD tc2_other_type_independent.
    " prototype: "gaps are allowed, other subtypes are independent"
    DATA(pernr) = hire( '20200101' ).
    add_address( pernr = pernr subty = '2' begda = '20210101' ).

    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).
    DATA(addr) = read_addr( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( addr ) exp = 2 ).
    " type 1 is untouched
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Subty exp = '1' ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD tc2_same_start_rejected.
    DATA(pernr) = hire( '20200101' ).
    add_address( pernr = pernr subty = '1' begda = '20200101' ).

    cl_abap_unit_assert=>assert_true( act = activate_fails( pernr ) msg = 'Same start within a type must be rejected' ).
  ENDMETHOD.

  METHOD tc2_delimit_moves_end.
    " prototype: "delimit works for time constraint 2"
    DATA(pernr) = hire( '20200101' ).
    DATA(addr) = read_addr( pernr ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Address
        EXECUTE Delimit FROM VALUE #( ( %tky = addr[ 1 ]-%tky  %param-NewEndda = '20210630' ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).

    addr = read_addr( pernr ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Endda exp = '20210630' ).
  ENDMETHOD.

  METHOD tc2_delimit_outside_rejected.
    " prototype: "delimit date must be inside the record"
    DATA(pernr) = hire( '20200101' ).
    DATA(addr) = read_addr( pernr ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Address
        EXECUTE Delimit FROM VALUE #( ( %tky = addr[ 1 ]-%tky  %param-NewEndda = '20191231' ) )
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( failed-address ).
    addr = read_addr( pernr ).
    cl_abap_unit_assert=>assert_equals( act = addr[ 1 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD reassign_writes_0000_0001.
    " prototype: "org reassignment writes 0000 and a new 0001 record"
    DATA(pernr) = hire( '20261101' ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Reassign FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                         %param = VALUE #( Begda = '20270101'
                                                           Massg = '02'
                                                           Bukrs = '1000'  Werks = '1000'  Btrtl = '0001'
                                                           Persg = '1'     Persk = 'K1'
                                                           Orgeh = '20000009'  Plans = '30000009'
                                                           Abkrs = 'K1' ) ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_false( prepare_fails( pernr ) ).

    DATA(actions) = read_actions( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( actions ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Endda exp = '20261231' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 2 ]-Massn exp = '02' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 2 ]-Stat2 exp = '3' ).

    DATA(org) = read_org( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( org ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = org[ 1 ]-Endda exp = '20261231' ).
    cl_abap_unit_assert=>assert_equals( act = org[ 2 ]-Orgeh exp = '20000009' ).
  ENDMETHOD.

  METHOD leave_sets_withdrawn.
    " prototype: "leaving sets the status to withdrawn from the action date"
    DATA(pernr) = hire( '20261101' ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Leave FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                      %param = VALUE #( Begda = '20270630'  Massg = '10' ) ) )
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( failed ).

    DATA(actions) = read_actions( pernr ).
    cl_abap_unit_assert=>assert_equals( act = lines( actions ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 1 ]-Endda exp = '20270629' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 2 ]-Massn exp = '10' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 2 ]-Stat2 exp = '0' ).
    cl_abap_unit_assert=>assert_equals( act = actions[ 2 ]-Endda exp = c_forever ).
  ENDMETHOD.

  METHOD action_on_leaver_rejected.
    " prototype: "actions on a leaver are rejected" (buttons are disabled)
    DATA(pernr) = hire( '20261101' ).
    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Leave FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                      %param = VALUE #( Begda = '20270630' ) ) ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Leave FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                      %param = VALUE #( Begda = '20280101' ) ) )
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-employee ).
    cl_abap_unit_assert=>assert_equals( act = lines( read_actions( pernr ) ) exp = 2 ).
  ENDMETHOD.

  METHOD same_day_action_rejected.
    " prototype: "same-day action is rejected as a whole"
    DATA(pernr) = hire( '20261101' ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Leave FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                      %param = VALUE #( Begda = '20261101' ) ) )
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-employee ).
    cl_abap_unit_assert=>assert_equals( act = lines( read_actions( pernr ) ) exp = 1 ).
  ENDMETHOD.

  METHOD display_user_cannot_hire.
    " authorization: display only (03) -> the PA40 hiring is not allowed
    set_authorization( '03' ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Hire FROM VALUE #( ( %cid   = 'HIRE'
                                     %param = VALUE #( Begda = '20261101'
                                                       Nachn = 'Test'      Vorna = 'Employee'
                                                       Gbdat = '19900101'  Gesch = '1'
                                                       Bukrs = '1000'      Werks = '1000'
                                                       Btrtl = '0001'      Persg = '1'
                                                       Persk = 'K1'        Orgeh = '20000001'
                                                       Plans = '30000001'  Abkrs = 'K1'
                                                       Stras = 'Street 1'  Ort01 = 'Seoul'
                                                       Land1 = 'KR' ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-employee ).
    cl_abap_unit_assert=>assert_initial( act = mapped-employee msg = 'No employee may be created' ).
  ENDMETHOD.

  METHOD action_before_hire_rejected.
    DATA(pernr) = hire( '20261101' ).

    MODIFY ENTITIES OF zr_pa_employee
      ENTITY Employee
        EXECUTE Leave FROM VALUE #( ( %tky   = VALUE #( %is_draft = if_abap_behv=>mk-on  Pernr = pernr )
                                      %param = VALUE #( Begda = '20260101' ) ) )
      FAILED DATA(failed).

    cl_abap_unit_assert=>assert_not_initial( act = failed-employee ).
    cl_abap_unit_assert=>assert_equals( act = lines( read_actions( pernr ) ) exp = 1 ).
  ENDMETHOD.

ENDCLASS.
