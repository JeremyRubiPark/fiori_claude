CLASS lcl_pa_auth DEFINITION ABSTRACT FINAL.
  PUBLIC SECTION.
    "! maintain (02) authorization for at least one personnel area
    CLASS-METHODS may_maintain_any
      RETURNING VALUE(result) TYPE abap_bool.
    "! maintain (02) authorization for the employee's current personnel area
    CLASS-METHODS may_maintain
      IMPORTING pernr         TYPE zpa_emp-pernr
      RETURNING VALUE(result) TYPE abap_bool.
  PRIVATE SECTION.
    CLASS-METHODS current_user
      RETURNING VALUE(result) TYPE zpa_auth-uname.
ENDCLASS.

CLASS lcl_pa_auth IMPLEMENTATION.

  METHOD current_user.
    result = cl_abap_context_info=>get_user_technical_name( ).
  ENDMETHOD.

  METHOD may_maintain_any.
    DATA(user) = current_user( ).
    SELECT SINGLE @abap_true FROM zpa_auth
      WHERE uname = @user AND actvt = '02'
      INTO @result.
  ENDMETHOD.

  METHOD may_maintain.
    DATA(user)  = current_user( ).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    " personnel area of the saved 0001 record valid today;
    " future hire -> the next record (like the prototype's key-date fallback);
    " otherwise (all records in the past) -> the latest record
    SELECT SINGLE werks FROM zpa_it0001
      WHERE pernr = @pernr AND begda <= @today AND endda >= @today
      INTO @DATA(werks).
    IF sy-subrc <> 0.
      SELECT SINGLE werks FROM zpa_it0001
        WHERE pernr = @pernr
          AND begda = ( SELECT MIN( begda ) FROM zpa_it0001
                          WHERE pernr = @pernr AND begda > @today )
        INTO @werks.
    ENDIF.
    IF sy-subrc <> 0.
      SELECT SINGLE werks FROM zpa_it0001
        WHERE pernr = @pernr
          AND begda = ( SELECT MAX( begda ) FROM zpa_it0001 WHERE pernr = @pernr )
        INTO @werks.
    ENDIF.

    SELECT SINGLE @abap_true FROM zpa_auth
      WHERE uname = @user AND actvt = '02'
        AND ( werks = '*' OR werks = @werks )
      INTO @result.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR Employee RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Employee RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Employee RESULT result.

    METHODS precheck_cba_Address FOR PRECHECK
       entities FOR CREATE Employee\_Address.

    METHODS precheck_cba_Orgassign FOR PRECHECK
       entities FOR CREATE Employee\_Orgassign.

    METHODS precheck_cba_Persdata FOR PRECHECK
       entities FOR CREATE Employee\_Persdata.

    METHODS Hire FOR MODIFY
       keys FOR ACTION Employee~Hire.

    METHODS Leave FOR MODIFY
       keys FOR ACTION Employee~Leave RESULT result.

    METHODS Reassign FOR MODIFY
       keys FOR ACTION Employee~Reassign RESULT result.

    METHODS checkActiveRecords FOR VALIDATE ON SAVE
       keys FOR Employee~checkActiveRecords.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Employee.

ENDCLASS.

CLASS lhc_Employee IMPLEMENTATION.

  METHOD get_instance_features.

    LOOP AT keys INTO DATA(key).

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersAction
          FIELDS ( Begda Stat2 ) WITH VALUE #( ( %tky = key-%tky ) )
        RESULT DATA(actions).
      SORT actions BY Begda DESCENDING.

      " no maintain authorization for this employee -> no Edit, no PA40 actions
      DATA(may_maintain) = lcl_pa_auth=>may_maintain( key-Pernr ).

      " latest personnel action = leaving -> no further reassignment / leaving
      DATA(has_left) = xsdbool( actions IS NOT INITIAL AND actions[ 1 ]-Stat2 = '0' ).

      DATA(edit_fc) = if_abap_behv=>fc-o-enabled.
      IF may_maintain = abap_false.
        edit_fc = if_abap_behv=>fc-o-disabled.
      ENDIF.

      DATA(action_fc) = if_abap_behv=>fc-o-enabled.
      IF has_left = abap_true OR may_maintain = abap_false.
        action_fc = if_abap_behv=>fc-o-disabled.
      ENDIF.

      APPEND VALUE #( %tky              = key-%tky
                      %action-Edit      = edit_fc
                      %action-Reassign  = action_fc
                      %action-Leave     = action_fc
                      %assoc-_OrgAssign = if_abap_behv=>fc-o-enabled
                      %assoc-_PersData  = if_abap_behv=>fc-o-enabled
                      %assoc-_Address   = if_abap_behv=>fc-o-enabled )
        TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.
    DATA(auth) = if_abap_behv=>auth-unauthorized.
    IF lcl_pa_auth=>may_maintain_any( ) = abap_true.
      auth = if_abap_behv=>auth-allowed.
    ENDIF.

    " update also controls the draft action Edit
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = auth.
    ENDIF.
    IF requested_authorizations-%action-Hire = if_abap_behv=>mk-on.
      result-%action-Hire = auth.
    ENDIF.
    IF requested_authorizations-%action-Reassign = if_abap_behv=>mk-on.
      result-%action-Reassign = auth.
    ENDIF.
    IF requested_authorizations-%action-Leave = if_abap_behv=>mk-on.
      result-%action-Leave = auth.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      DATA(auth) = if_abap_behv=>auth-unauthorized.
      IF lcl_pa_auth=>may_maintain( key-Pernr ) = abap_true.
        auth = if_abap_behv=>auth-allowed.
      ENDIF.

      APPEND VALUE #( %tky             = key-%tky
                      %update          = auth
                      %action-Reassign = auth
                      %action-Leave    = auth ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_cba_Address.
  ENDMETHOD.

  METHOD precheck_cba_Orgassign.
  ENDMETHOD.

  METHOD precheck_cba_Persdata.
  ENDMETHOD.

  METHOD Hire.

    CONSTANTS c_forever TYPE d VALUE '99991231'.

    LOOP AT keys INTO DATA(key).
      DATA(p) = key-%param.

      " ---- required parameters (prototype: REQUIRED -> nothing is saved)
      DATA(missing) = VALUE string_table(
        ( COND #( WHEN p-Begda IS INITIAL THEN `Start Date of Action` ) )
        ( COND #( WHEN p-Nachn IS INITIAL THEN `Last Name` ) )
        ( COND #( WHEN p-Vorna IS INITIAL THEN `First Name` ) )
        ( COND #( WHEN p-Gbdat IS INITIAL THEN `Date of Birth` ) )
        ( COND #( WHEN p-Gesch IS INITIAL THEN `Gender` ) )
        ( COND #( WHEN p-Bukrs IS INITIAL THEN `Company Code` ) )
        ( COND #( WHEN p-Werks IS INITIAL THEN `Personnel Area` ) )
        ( COND #( WHEN p-Btrtl IS INITIAL THEN `Personnel Subarea` ) )
        ( COND #( WHEN p-Persg IS INITIAL THEN `Employee Group` ) )
        ( COND #( WHEN p-Persk IS INITIAL THEN `Employee Subgroup` ) )
        ( COND #( WHEN p-Orgeh IS INITIAL THEN `Organizational Unit` ) )
        ( COND #( WHEN p-Plans IS INITIAL THEN `Position` ) )
        ( COND #( WHEN p-Abkrs IS INITIAL THEN `Payroll Area` ) )
        ( COND #( WHEN p-Stras IS INITIAL THEN `Street` ) )
        ( COND #( WHEN p-Ort01 IS INITIAL THEN `City` ) )
        ( COND #( WHEN p-Land1 IS INITIAL THEN `Country` ) ) ).
      DELETE missing WHERE table_line IS INITIAL.

      IF missing IS NOT INITIAL.
        APPEND VALUE #( %cid = key-%cid ) TO failed-employee.
        APPEND VALUE #( %cid = key-%cid
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Hiring not executed: { missing[ 1 ] } missing| ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.

      " ---- one deep create: employee + info group of the hiring action
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee
          CREATE FROM VALUE #( ( %cid      = key-%cid
                                 %is_draft = if_abap_behv=>mk-on ) )

          CREATE BY \_PersAction
            FIELDS ( Begda Endda Massn Massg Stat2 )
            WITH VALUE #( ( %cid_ref  = key-%cid
                            %is_draft = if_abap_behv=>mk-on
                            %target   = VALUE #( ( %cid      = |{ key-%cid }_0000|
                                                   %is_draft = if_abap_behv=>mk-on
                                                   Begda     = p-Begda
                                                   Endda     = c_forever
                                                   Massn     = '01'          " Hiring
                                                   Massg     = p-Massg
                                                   Stat2     = '3' ) ) ) )  " Active

          CREATE BY \_PersData
            FIELDS ( Begda Endda Anred Nachn Vorna Gbdat Gesch Natio Sprsl Famst Anzkd )
            WITH VALUE #( ( %cid_ref  = key-%cid
                            %is_draft = if_abap_behv=>mk-on
                            %target   = VALUE #( ( %cid      = |{ key-%cid }_0002|
                                                   %is_draft = if_abap_behv=>mk-on
                                                   Begda     = p-Begda
                                                   Endda     = c_forever
                                                   Anred     = p-Anred
                                                   Nachn     = p-Nachn
                                                   Vorna     = p-Vorna
                                                   Gbdat     = p-Gbdat
                                                   Gesch     = p-Gesch
                                                   Natio     = p-Natio
                                                   Sprsl     = p-Sprsl
                                                   Famst     = p-Famst
                                                   Anzkd     = p-Anzkd ) ) ) )

          CREATE BY \_OrgAssign
            FIELDS ( Begda Endda Bukrs Werks Btrtl Persg Persk Orgeh Plans Stell Kostl Abkrs )
            WITH VALUE #( ( %cid_ref  = key-%cid
                            %is_draft = if_abap_behv=>mk-on
                            %target   = VALUE #( ( %cid      = |{ key-%cid }_0001|
                                                   %is_draft = if_abap_behv=>mk-on
                                                   Begda     = p-Begda
                                                   Endda     = c_forever
                                                   Bukrs     = p-Bukrs
                                                   Werks     = p-Werks
                                                   Btrtl     = p-Btrtl
                                                   Persg     = p-Persg
                                                   Persk     = p-Persk
                                                   Orgeh     = p-Orgeh
                                                   Plans     = p-Plans
                                                   Stell     = p-Stell
                                                   Kostl     = p-Kostl
                                                   Abkrs     = p-Abkrs ) ) ) )

          CREATE BY \_Address
            FIELDS ( Subty Begda Endda Stras Ort01 Pstlz Land1 Telnr )
            WITH VALUE #( ( %cid_ref  = key-%cid
                            %is_draft = if_abap_behv=>mk-on
                            %target   = VALUE #( ( %cid      = |{ key-%cid }_0006|
                                                   %is_draft = if_abap_behv=>mk-on
                                                   Subty     = '1'          " Permanent residence
                                                   Begda     = p-Begda
                                                   Endda     = c_forever
                                                   Stras     = p-Stras
                                                   Ort01     = p-Ort01
                                                   Pstlz     = p-Pstlz
                                                   Land1     = p-Land1
                                                   Telnr     = p-Telnr ) ) ) )

        MAPPED   DATA(hire_mapped)
        FAILED   DATA(hire_failed)
        REPORTED DATA(hire_reported).

      " ---- hand the new employee back to Fiori (factory action result)
      APPEND LINES OF hire_mapped-employee TO mapped-employee.
      APPEND LINES OF hire_failed-employee TO failed-employee.
      APPEND LINES OF hire_reported-employee TO reported-employee.

    ENDLOOP.

  ENDMETHOD.

  METHOD Leave.

    LOOP AT keys INTO DATA(key).
      DATA(p) = key-%param.
      DATA(problem) = ``.

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersAction
          ALL FIELDS WITH VALUE #( ( %tky = key-%tky ) )
        RESULT DATA(actions).

      DATA(found) = abap_false.
      LOOP AT actions INTO DATA(current) WHERE Begda <= p-Begda AND Endda >= p-Begda.
        found = abap_true.
        EXIT.
      ENDLOOP.

      IF p-Begda IS INITIAL.
        problem = `start date is required`.
      ELSEIF found = abap_false.
        problem = |{ p-Begda DATE = USER } is before hiring|.
      ELSEIF current-Stat2 = '0'.
        problem = |employee left on { current-Begda DATE = USER }|.
      ELSEIF current-Begda = p-Begda.
        problem = |action exists on { p-Begda DATE = USER }|.
      ENDIF.

      IF problem IS NOT INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-employee.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Leaving: { problem }| ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.

      " ---- delimit the current 0000 and write 0000 (10) with status 0 = withdrawn
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY PersAction
          UPDATE FIELDS ( Endda )
          WITH VALUE #( ( %tky = current-%tky  Endda = CONV d( p-Begda - 1 ) ) )

        ENTITY Employee
          CREATE BY \_PersAction
            FIELDS ( Begda Endda Massn Massg Stat2 )
            WITH VALUE #( ( %tky    = key-%tky
                            %target = VALUE #( ( %cid      = |{ key-Pernr }_0000|
                                                 %is_draft = key-%is_draft
                                                 Begda     = p-Begda
                                                 Endda     = current-Endda
                                                 Massn     = '10'
                                                 Massg     = p-Massg
                                                 Stat2     = '0' ) ) ) )
        FAILED   DATA(mod_failed)
        REPORTED DATA(mod_reported).

      APPEND LINES OF mod_failed-employee   TO failed-employee.
      APPEND LINES OF mod_reported-employee TO reported-employee.
    ENDLOOP.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Employee
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(employees).
    result = VALUE #( FOR e IN employees ( %tky = e-%tky  %param = e ) ).

  ENDMETHOD.

  METHOD Reassign.

    LOOP AT keys INTO DATA(key).
      DATA(p) = key-%param.
      DATA(problem) = ``.

      " ---- personnel action valid on the action date
      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersAction
          ALL FIELDS WITH VALUE #( ( %tky = key-%tky ) )
        RESULT DATA(actions).

      DATA(found) = abap_false.
      LOOP AT actions INTO DATA(current) WHERE Begda <= p-Begda AND Endda >= p-Begda.
        found = abap_true.
        EXIT.
      ENDLOOP.

      IF p-Begda IS INITIAL.
        problem = `start date is required`.
      ELSEIF found = abap_false.
        problem = |{ p-Begda DATE = USER } is before hiring|.
      ELSEIF current-Stat2 = '0'.
        problem = |employee left on { current-Begda DATE = USER }|.
      ELSEIF current-Begda = p-Begda.
        problem = |action exists on { p-Begda DATE = USER }|.
      ELSE.
        DATA(missing) = VALUE string_table(
          ( COND #( WHEN p-Bukrs IS INITIAL THEN `Company Code` ) )
          ( COND #( WHEN p-Werks IS INITIAL THEN `Personnel Area` ) )
          ( COND #( WHEN p-Btrtl IS INITIAL THEN `Personnel Subarea` ) )
          ( COND #( WHEN p-Persg IS INITIAL THEN `Employee Group` ) )
          ( COND #( WHEN p-Persk IS INITIAL THEN `Employee Subgroup` ) )
          ( COND #( WHEN p-Orgeh IS INITIAL THEN `Organizational Unit` ) )
          ( COND #( WHEN p-Plans IS INITIAL THEN `Position` ) )
          ( COND #( WHEN p-Abkrs IS INITIAL THEN `Payroll Area` ) ) ).
        DELETE missing WHERE table_line IS INITIAL.
        IF missing IS NOT INITIAL.
          problem = |{ missing[ 1 ] } missing|.
        ENDIF.
      ENDIF.

      IF problem IS NOT INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-employee.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Reassign: { problem }| ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.

      " ---- delimit the current 0000, write 0000 (02) and the new 0001
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY PersAction
          UPDATE FIELDS ( Endda )
          WITH VALUE #( ( %tky = current-%tky  Endda = CONV d( p-Begda - 1 ) ) )

        ENTITY Employee
          CREATE BY \_PersAction
            FIELDS ( Begda Endda Massn Massg Stat2 )
            WITH VALUE #( ( %tky    = key-%tky
                            %target = VALUE #( ( %cid      = |{ key-Pernr }_0000|
                                                 %is_draft = key-%is_draft
                                                 Begda     = p-Begda
                                                 Endda     = current-Endda
                                                 Massn     = '02'
                                                 Massg     = p-Massg
                                                 Stat2     = current-Stat2 ) ) ) )

          CREATE BY \_OrgAssign
            FIELDS ( Begda Endda Bukrs Werks Btrtl Persg Persk Orgeh Plans Stell Kostl Abkrs )
            WITH VALUE #( ( %tky    = key-%tky
                            %target = VALUE #( ( %cid      = |{ key-Pernr }_0001|
                                                 %is_draft = key-%is_draft
                                                 Begda     = p-Begda
                                                 Endda     = '99991231'
                                                 Bukrs     = p-Bukrs
                                                 Werks     = p-Werks
                                                 Btrtl     = p-Btrtl
                                                 Persg     = p-Persg
                                                 Persk     = p-Persk
                                                 Orgeh     = p-Orgeh
                                                 Plans     = p-Plans
                                                 Stell     = p-Stell
                                                 Kostl     = p-Kostl
                                                 Abkrs     = p-Abkrs ) ) ) )
        FAILED   DATA(mod_failed)
        REPORTED DATA(mod_reported).

      APPEND LINES OF mod_failed-employee   TO failed-employee.
      APPEND LINES OF mod_reported-employee TO reported-employee.
    ENDLOOP.

    " ---- result [1] $self
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Employee
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(employees).
    result = VALUE #( FOR e IN employees ( %tky = e-%tky  %param = e ) ).

  ENDMETHOD.


  METHOD checkActiveRecords.
  ENDMETHOD.

  METHOD earlynumbering_create.

    " Instances that already have a Pernr (e.g. while a draft is activated) keep it.
    " This makes the method safe to be called again for the same instance.
    LOOP AT entities INTO DATA(entity) WHERE Pernr IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-employee.
    ENDLOOP.

    DATA(new_entities) = entities.
    DELETE new_entities WHERE Pernr IS NOT INITIAL.
    IF new_entities IS INITIAL.
      RETURN.
    ENDIF.

    " Draft table: generated by the ADT quick fix, columns are named like the CDS elements.
    SELECT SINGLE FROM zpa_emp   FIELDS MAX( pernr ) INTO @DATA(max_active).
    SELECT SINGLE FROM zpa_emp_d FIELDS MAX( pernr ) INTO @DATA(max_draft).

    " First employee gets 10000001 (same number range as the Fiori prototype).
    DATA(next_pernr) = nmax( val1 = CONV i( max_active )
                             val2 = CONV i( max_draft )
                             val3 = 10000000 ).

    LOOP AT new_entities INTO entity.
      next_pernr += 1.
      entity-Pernr = next_pernr.
      APPEND VALUE #( %cid      = entity-%cid
                      %key      = entity-%key
                      %is_draft = entity-%is_draft ) TO mapped-employee.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_PersAction DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS applyTimeConstraint FOR DETERMINE ON MODIFY
       keys FOR PersAction~applyTimeConstraint.

ENDCLASS.

CLASS lhc_PersAction IMPLEMENTATION.

  METHOD applyTimeConstraint.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_OrgAssign DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR OrgAssign RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR OrgAssign RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR OrgAssign RESULT result.

    METHODS RemoveRecord FOR MODIFY
       keys FOR ACTION OrgAssign~RemoveRecord.

    METHODS applyTimeConstraint FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrgAssign~applyTimeConstraint.

    METHODS checkMandatory FOR VALIDATE ON SAVE
       keys FOR OrgAssign~checkMandatory.

    METHODS checkTimeConstraint FOR VALIDATE ON SAVE
       keys FOR OrgAssign~checkTimeConstraint.

ENDCLASS.

CLASS lhc_OrgAssign IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY OrgAssign
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    LOOP AT records INTO DATA(rec).

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_OrgAssign
          FIELDS ( RecordUuid )
          WITH VALUE #( ( %is_draft = rec-%is_draft
                          Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).

      APPEND VALUE #( %tky                 = rec-%tky
                      %update              = if_abap_behv=>fc-o-enabled
                      %action-RemoveRecord = COND #( WHEN lines( siblings ) > 1
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled ) )
        TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-RemoveRecord = if_abap_behv=>mk-on.
      result-%action-RemoveRecord = COND #( WHEN lcl_pa_auth=>may_maintain_any( ) = abap_true
                                            THEN if_abap_behv=>auth-allowed
                                            ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY OrgAssign
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    result = VALUE #( FOR r IN records
                      ( %tky                 = r-%tky
                        %action-RemoveRecord = COND #( WHEN lcl_pa_auth=>may_maintain( r-Pernr ) = abap_true
                                                       THEN if_abap_behv=>auth-allowed
                                                       ELSE if_abap_behv=>auth-unauthorized ) ) ).
  ENDMETHOD.

  METHOD RemoveRecord.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY OrgAssign
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(targets).

    LOOP AT targets INTO DATA(rec).

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_OrgAssign
          FIELDS ( Begda Endda )
          WITH VALUE #( ( %is_draft = rec-%is_draft
                          Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).
      SORT siblings BY Begda.

      " ---- the only record of the employee cannot be deleted
      IF lines( siblings ) <= 1.
        APPEND VALUE #( %tky = rec-%tky ) TO failed-orgassign.
        APPEND VALUE #( %tky = rec-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'The last record of an infotype cannot be deleted' ) )
          TO reported-orgassign.
        CONTINUE.
      ENDIF.

      DATA(idx) = line_index( siblings[ RecordUuid = rec-RecordUuid ] ).

      IF idx = 1.
        " ---- first record: the next record takes over its start date
        DATA(next) = siblings[ 2 ].
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY OrgAssign
            UPDATE FIELDS ( Begda )
            WITH VALUE #( ( %tky = next-%tky  Begda = rec-Begda ) ).
        APPEND VALUE #( %tky = next-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Next record now starts on { rec-Begda DATE = USER }| ) )
          TO reported-orgassign.
      ELSE.
        " ---- otherwise: the previous record is stretched over the gap
        DATA(prev) = siblings[ idx - 1 ].
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY OrgAssign
            UPDATE FIELDS ( Endda )
            WITH VALUE #( ( %tky = prev-%tky  Endda = rec-Endda ) ).
        APPEND VALUE #( %tky = prev-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Previous record now ends on { rec-Endda DATE = USER }| ) )
          TO reported-orgassign.
      ENDIF.

      " ---- delete the record itself ("internal delete" is allowed in local mode)
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY OrgAssign
          DELETE FROM VALUE #( ( %tky = rec-%tky ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD applyTimeConstraint.

    CONSTANTS c_forever TYPE d VALUE '99991231'.
    DATA tail_no TYPE i.     " unique %cid for split-off tail records

    " The records that were just created (draft or active).
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY OrgAssign
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(new_records).

    LOOP AT new_records INTO DATA(rec).

      " All 0001 records of the same employee, in the same draft/active state.
      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_OrgAssign
          ALL FIELDS WITH VALUE #( ( %is_draft = rec-%is_draft
                                     Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).
      DELETE siblings WHERE RecordUuid = rec-RecordUuid.

      " ---- first record of this infotype: must reach until 9999-12-31
      IF siblings IS INITIAL.
        IF rec-Endda <> c_forever.
          MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
            ENTITY OrgAssign
              UPDATE FIELDS ( Endda )
              WITH VALUE #( ( %tky = rec-%tky  Endda = c_forever ) ).
        ENDIF.
        CONTINUE.
      ENDIF.

      " ---- record that covers the rec start date
      DATA(found) = abap_false.
      LOOP AT siblings INTO DATA(covering)
           WHERE Begda < rec-Begda AND Endda >= rec-Begda.
        found = abap_true.
        EXIT.
      ENDLOOP.
      IF found = abap_false.
        " Before the first record or same start date -> precheck / validation.
        " Also the case for the tail record created below (nothing covers it).
        CONTINUE.
      ENDIF.

      DATA(old_end)  = covering-Endda.
      DATA(prev_end) = CONV d( rec-Begda - 1 ).
      DATA(new_end)  = COND d( WHEN rec-Endda IS INITIAL OR rec-Endda > old_end
                               THEN old_end
                               ELSE rec-Endda ).

      " ---- delimit the covering record, set the end date of the rec record
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY OrgAssign
          UPDATE FIELDS ( Endda )
          WITH VALUE #( ( %tky = covering-%tky  Endda = prev_end )
                        ( %tky = rec-%tky       Endda = new_end ) ).

      APPEND VALUE #( %tky = rec-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |Previous record delimited to { prev_end DATE = USER }| ) )
        TO reported-orgassign.

      " ---- rec record ends earlier: the rest of the old period comes back
      IF new_end < old_end.
        tail_no += 1.
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Employee
            CREATE BY \_OrgAssign
            FIELDS ( Begda Endda Bukrs Werks Btrtl Persg Persk Orgeh Plans Stell Kostl Abkrs )
            WITH VALUE #( ( %is_draft = rec-%is_draft
                            Pernr     = rec-Pernr
                            %target   = VALUE #( ( %cid      = |TAIL{ tail_no }|
                                                 %is_draft = rec-%is_draft
                                                 Begda     = CONV d( new_end + 1 )
                                                 Endda     = old_end
                                                 Bukrs     = covering-Bukrs
                                                 Werks     = covering-Werks
                                                 Btrtl     = covering-Btrtl
                                                 Persg     = covering-Persg
                                                 Persk     = covering-Persk
                                                 Orgeh     = covering-Orgeh
                                                 Plans     = covering-Plans
                                                 Stell     = covering-Stell
                                                 Kostl     = covering-Kostl
                                                 Abkrs     = covering-Abkrs ) ) ) ).

        APPEND VALUE #( %tky = rec-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Old values restored from { CONV d( new_end + 1 ) DATE = USER }| ) )
          TO reported-orgassign.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD checkMandatory.
  ENDMETHOD.

  METHOD checkTimeConstraint.

    CONSTANTS c_forever TYPE d VALUE '99991231'.
    DATA problem TYPE string.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY OrgAssign
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(changed).

    " One check per employee, even if several of its records were changed.
    LOOP AT changed INTO DATA(changed_rec)
         GROUP BY ( pernr    = changed_rec-Pernr
                    is_draft = changed_rec-%is_draft ) INTO DATA(emp).

      CLEAR problem.

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_OrgAssign
          FIELDS ( Begda Endda )
          WITH VALUE #( ( %is_draft = emp-is_draft
                          Pernr     = emp-pernr ) )
        RESULT DATA(records).
      SORT records BY Begda.

      " ---- BEFORE_FIRST: a NEW record must not start before the first saved record.
      " Only checked on the draft (Prepare): a record is new if it has no active twin.
      IF emp-is_draft = if_abap_behv=>mk-on.
        READ ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Employee BY \_OrgAssign
            FIELDS ( Begda )
            WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                            Pernr     = emp-pernr ) )
          RESULT DATA(active_records).

        IF active_records IS NOT INITIAL.
          SORT active_records BY Begda.
          DATA(first_begda) = active_records[ 1 ]-Begda.

          LOOP AT records INTO DATA(candidate)
               WHERE Begda < first_begda.
            IF NOT line_exists( active_records[ RecordUuid = candidate-RecordUuid ] ).
              problem = |Starts before first record ({ first_begda DATE = USER })|.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.

      LOOP AT records INTO DATA(rec).
        DATA(idx) = sy-tabix.
        IF problem IS NOT INITIAL.
          EXIT.
        ENDIF.

        IF rec-Endda IS INITIAL OR rec-Endda < rec-Begda.
          problem = |End date missing or before start ({ rec-Begda DATE = USER })|.
          EXIT.
        ENDIF.

        IF idx > 1.
          DATA(prev) = records[ idx - 1 ].
          IF rec-Begda = prev-Begda.
            problem = |Two records start on { rec-Begda DATE = USER }|.
            EXIT.
          ELSEIF rec-Begda <> CONV d( prev-Endda + 1 ).
            problem = |Gap or overlap after record ending { prev-Endda DATE = USER }|.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF problem IS INITIAL AND records IS NOT INITIAL.
        DATA(last) = records[ lines( records ) ].
        IF last-Endda <> c_forever.
          problem = |The last record must end on { c_forever DATE = USER }|.
        ENDIF.
      ENDIF.

      " Report on every changed record of this employee, with the start date marked.
      LOOP AT GROUP emp INTO DATA(member).
        " clear messages of earlier checks
        APPEND VALUE #( %tky        = member-%tky
                        %state_area = 'TIME_CONSTRAINT'
                        %path       = VALUE #( employee-%is_draft = member-%is_draft
                                               employee-Pernr     = member-Pernr ) )
          TO reported-orgassign.

        IF problem IS NOT INITIAL.
          APPEND VALUE #( %tky = member-%tky ) TO failed-orgassign.
          APPEND VALUE #( %tky          = member-%tky
                          %state_area   = 'TIME_CONSTRAINT'
                          %path         = VALUE #( employee-%is_draft = member-%is_draft
                                                   employee-Pernr     = member-Pernr )
                          %msg          = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = problem )
                          %element-Begda = if_abap_behv=>mk-on ) TO reported-orgassign.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_PersData DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR PersData RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR PersData RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR PersData RESULT result.

    METHODS RemoveRecord FOR MODIFY
       keys FOR ACTION PersData~RemoveRecord.

    METHODS applyTimeConstraint FOR DETERMINE ON SAVE
       keys FOR PersData~applyTimeConstraint.

    METHODS checkMandatory FOR VALIDATE ON SAVE
       keys FOR PersData~checkMandatory.

    METHODS checkTimeConstraint FOR VALIDATE ON SAVE
       keys FOR PersData~checkTimeConstraint.

ENDCLASS.

CLASS lhc_PersData IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY PersData
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    LOOP AT records INTO DATA(rec).

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersData
          FIELDS ( RecordUuid )
          WITH VALUE #( ( %is_draft = rec-%is_draft
                          Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).

      APPEND VALUE #( %tky                 = rec-%tky
                      %update              = if_abap_behv=>fc-o-enabled
                      %action-RemoveRecord = COND #( WHEN lines( siblings ) > 1
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled ) )
        TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_global_authorizations.
    IF requested_authorizations-%action-RemoveRecord = if_abap_behv=>mk-on.
      result-%action-RemoveRecord = COND #( WHEN lcl_pa_auth=>may_maintain_any( ) = abap_true
                                            THEN if_abap_behv=>auth-allowed
                                            ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY PersData
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    result = VALUE #( FOR r IN records
                      ( %tky                 = r-%tky
                        %action-RemoveRecord = COND #( WHEN lcl_pa_auth=>may_maintain( r-Pernr ) = abap_true
                                                       THEN if_abap_behv=>auth-allowed
                                                       ELSE if_abap_behv=>auth-unauthorized ) ) ).
  ENDMETHOD.

  METHOD RemoveRecord.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY PersData
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(targets).

    LOOP AT targets INTO DATA(rec).

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersData
          FIELDS ( Begda Endda )
          WITH VALUE #( ( %is_draft = rec-%is_draft
                          Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).
      SORT siblings BY Begda.

      " ---- the only record of the employee cannot be deleted
      IF lines( siblings ) <= 1.
        APPEND VALUE #( %tky = rec-%tky ) TO failed-persdata.
        APPEND VALUE #( %tky = rec-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'The last record of an infotype cannot be deleted' ) )
          TO reported-persdata.
        CONTINUE.
      ENDIF.

      DATA(idx) = line_index( siblings[ RecordUuid = rec-RecordUuid ] ).

      IF idx = 1.
        " ---- first record: the next record takes over its start date
        DATA(next) = siblings[ 2 ].
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY PersData
            UPDATE FIELDS ( Begda )
            WITH VALUE #( ( %tky = next-%tky  Begda = rec-Begda ) ).
        APPEND VALUE #( %tky = next-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Next record now starts on { rec-Begda DATE = USER }| ) )
          TO reported-persdata.
      ELSE.
        " ---- otherwise: the previous record is stretched over the gap
        DATA(prev) = siblings[ idx - 1 ].
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY PersData
            UPDATE FIELDS ( Endda )
            WITH VALUE #( ( %tky = prev-%tky  Endda = rec-Endda ) ).
        APPEND VALUE #( %tky = prev-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Previous record now ends on { rec-Endda DATE = USER }| ) )
          TO reported-persdata.
      ENDIF.

      " ---- delete the record itself ("internal delete" is allowed in local mode)
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY PersData
          DELETE FROM VALUE #( ( %tky = rec-%tky ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD applyTimeConstraint.

    CONSTANTS c_forever TYPE d VALUE '99991231'.
    DATA tail_no TYPE i.     " unique %cid for split-off tail records

    " The records that were just created (draft or active).
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY PersData
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(new_records).

    LOOP AT new_records INTO DATA(rec).

      " All 0002 records of the same employee, in the same draft/active state.
      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersData
          ALL FIELDS WITH VALUE #( ( %is_draft = rec-%is_draft
                                     Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).
      DELETE siblings WHERE RecordUuid = rec-RecordUuid.

      " ---- first record of this infotype: must reach until 9999-12-31
      IF siblings IS INITIAL.
        IF rec-Endda <> c_forever.
          MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
            ENTITY PersData
              UPDATE FIELDS ( Endda )
              WITH VALUE #( ( %tky = rec-%tky  Endda = c_forever ) ).
        ENDIF.
        CONTINUE.
      ENDIF.

      " ---- record that covers the rec start date
      DATA(found) = abap_false.
      LOOP AT siblings INTO DATA(covering)
           WHERE Begda < rec-Begda AND Endda >= rec-Begda.
        found = abap_true.
        EXIT.
      ENDLOOP.
      IF found = abap_false.
        " Before the first record or same start date -> precheck / validation.
        " Also the case for the tail record created below (nothing covers it).
        CONTINUE.
      ENDIF.

      DATA(old_end)  = covering-Endda.
      DATA(prev_end) = CONV d( rec-Begda - 1 ).
      DATA(new_end)  = COND d( WHEN rec-Endda IS INITIAL OR rec-Endda > old_end
                               THEN old_end
                               ELSE rec-Endda ).

      " ---- delimit the covering record, set the end date of the rec record
      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY PersData
          UPDATE FIELDS ( Endda )
          WITH VALUE #( ( %tky = covering-%tky  Endda = prev_end )
                        ( %tky = rec-%tky       Endda = new_end ) ).

      APPEND VALUE #( %tky = rec-%tky
                      %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |Previous record delimited to { prev_end DATE = USER }| ) )
        TO reported-persdata.

      " ---- rec record ends earlier: the rest of the old period comes back
      IF new_end < old_end.
        tail_no += 1.
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Employee
            CREATE BY \_PersData
            FIELDS ( Begda Endda Anred Nachn Vorna Gbdat Gesch Natio Sprsl Famst Anzkd )
            WITH VALUE #( ( %is_draft = rec-%is_draft
                            Pernr     = rec-Pernr
                            %target   = VALUE #( ( %cid      = |TAIL{ tail_no }|
                                                 %is_draft = rec-%is_draft
                                                 Begda     = CONV d( new_end + 1 )
                                                 Endda     = old_end
                                                 Anred     = covering-Anred
                                                 Nachn     = covering-Nachn
                                                 Vorna     = covering-Vorna
                                                 Gbdat     = covering-Gbdat
                                                 Gesch     = covering-Gesch
                                                 Natio     = covering-Natio
                                                 Sprsl     = covering-Sprsl
                                                 Famst     = covering-Famst
                                                 Anzkd     = covering-Anzkd ) ) ) ).

        APPEND VALUE #( %tky = rec-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = |Old values restored from { CONV d( new_end + 1 ) DATE = USER }| ) )
          TO reported-persdata.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD checkMandatory.
  ENDMETHOD.

  METHOD checkTimeConstraint.

    CONSTANTS c_forever TYPE d VALUE '99991231'.
    DATA problem TYPE string.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY PersData
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(changed).

    " One check per employee, even if several of its records were changed.
    LOOP AT changed INTO DATA(changed_rec)
         GROUP BY ( pernr    = changed_rec-Pernr
                    is_draft = changed_rec-%is_draft ) INTO DATA(emp).

      CLEAR problem.

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_PersData
          FIELDS ( Begda Endda )
          WITH VALUE #( ( %is_draft = emp-is_draft
                          Pernr     = emp-pernr ) )
        RESULT DATA(records).
      SORT records BY Begda.

      " ---- BEFORE_FIRST: a NEW record must not start before the first saved record.
      " Only checked on the draft (Prepare): a record is new if it has no active twin.
      IF emp-is_draft = if_abap_behv=>mk-on.
        READ ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Employee BY \_PersData
            FIELDS ( Begda )
            WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                            Pernr     = emp-pernr ) )
          RESULT DATA(active_records).

        IF active_records IS NOT INITIAL.
          SORT active_records BY Begda.
          DATA(first_begda) = active_records[ 1 ]-Begda.

          LOOP AT records INTO DATA(candidate)
               WHERE Begda < first_begda.
            IF NOT line_exists( active_records[ RecordUuid = candidate-RecordUuid ] ).
              problem = |Starts before first record ({ first_begda DATE = USER })|.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.

      LOOP AT records INTO DATA(rec).
        DATA(idx) = sy-tabix.
        IF problem IS NOT INITIAL.
          EXIT.
        ENDIF.

        IF rec-Endda IS INITIAL OR rec-Endda < rec-Begda.
          problem = |End date missing or before start ({ rec-Begda DATE = USER })|.
          EXIT.
        ENDIF.

        IF idx > 1.
          DATA(prev) = records[ idx - 1 ].
          IF rec-Begda = prev-Begda.
            problem = |Two records start on { rec-Begda DATE = USER }|.
            EXIT.
          ELSEIF rec-Begda <> CONV d( prev-Endda + 1 ).
            problem = |Gap or overlap after record ending { prev-Endda DATE = USER }|.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF problem IS INITIAL AND records IS NOT INITIAL.
        DATA(last) = records[ lines( records ) ].
        IF last-Endda <> c_forever.
          problem = |The last record must end on { c_forever DATE = USER }|.
        ENDIF.
      ENDIF.

      " Report on every changed record of this employee, with the start date marked.
      LOOP AT GROUP emp INTO DATA(member).
        " clear messages of earlier checks
        APPEND VALUE #( %tky        = member-%tky
                        %state_area = 'TIME_CONSTRAINT'
                        %path       = VALUE #( employee-%is_draft = member-%is_draft
                                               employee-Pernr     = member-Pernr ) )
          TO reported-persdata.

        IF problem IS NOT INITIAL.
          APPEND VALUE #( %tky = member-%tky ) TO failed-persdata.
          APPEND VALUE #( %tky          = member-%tky
                          %state_area   = 'TIME_CONSTRAINT'
                          %path         = VALUE #( employee-%is_draft = member-%is_draft
                                                   employee-Pernr     = member-Pernr )
                          %msg          = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = problem )
                          %element-Begda = if_abap_behv=>mk-on ) TO reported-persdata.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


ENDCLASS.

CLASS lhc_Address DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR Address RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Address RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Address RESULT result.

    METHODS Delimit FOR MODIFY
       keys FOR ACTION Address~Delimit RESULT result.

    METHODS applyTimeConstraint FOR DETERMINE ON SAVE
       keys FOR Address~applyTimeConstraint.

    METHODS checkMandatory FOR VALIDATE ON SAVE
       keys FOR Address~checkMandatory.

    METHODS checkTimeConstraint FOR VALIDATE ON SAVE
       keys FOR Address~checkTimeConstraint.

ENDCLASS.

CLASS lhc_Address IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        FIELDS ( Endda ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    " Update, delete and Delimit are always enabled; the action itself checks the date.
    result = VALUE #( FOR r IN records
                      ( %tky           = r-%tky
                        %update        = if_abap_behv=>fc-o-enabled
                        %delete        = if_abap_behv=>fc-o-enabled
                        %action-Delimit = if_abap_behv=>fc-o-enabled ) ).

  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-Delimit = if_abap_behv=>mk-on.
      result-%action-Delimit = COND #( WHEN lcl_pa_auth=>may_maintain_any( ) = abap_true
                                       THEN if_abap_behv=>auth-allowed
                                       ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    result = VALUE #( FOR r IN records
                      ( %tky            = r-%tky
                        %action-Delimit = COND #( WHEN lcl_pa_auth=>may_maintain( r-Pernr ) = abap_true
                                                  THEN if_abap_behv=>auth-allowed
                                                  ELSE if_abap_behv=>auth-unauthorized ) ) ).
  ENDMETHOD.

  METHOD Delimit.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    LOOP AT records INTO DATA(rec).
      DATA(new_end) = keys[ KEY id  %tky = rec-%tky ]-%param-NewEndda.

      " DELIMIT_INVALID: the new end date must lie between Begda and the old Endda - 1
      IF new_end IS INITIAL OR new_end < rec-Begda OR new_end >= rec-Endda.
        APPEND VALUE #( %tky = rec-%tky ) TO failed-address.
        APPEND VALUE #( %tky  = rec-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg  = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-error
                                  text     = |End date must be { rec-Begda DATE = USER } - { CONV d( rec-Endda - 1 ) DATE = USER }| ) )
          TO reported-address.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Address
          UPDATE FIELDS ( Endda )
          WITH VALUE #( ( %tky = rec-%tky  Endda = new_end ) ).
    ENDLOOP.

    " return the changed records (result [1] $self)
    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(changed).
    result = VALUE #( FOR r IN changed ( %tky = r-%tky  %param = r ) ).

  ENDMETHOD.


  METHOD applyTimeConstraint.

    CONSTANTS c_forever TYPE d VALUE '99991231'.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(new_records).

    LOOP AT new_records INTO DATA(rec).

      " ---- empty end date: valid until further notice
      IF rec-Endda IS INITIAL.
        rec-Endda = c_forever.
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Address
            UPDATE FIELDS ( Endda )
            WITH VALUE #( ( %tky = rec-%tky  Endda = c_forever ) ).
      ENDIF.

      " ---- records of the same employee AND the same address type
      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_Address
          FIELDS ( Subty Begda Endda )
          WITH VALUE #( ( %is_draft = rec-%is_draft
                          Pernr     = rec-Pernr ) )
        RESULT DATA(siblings).
      DELETE siblings WHERE RecordUuid = rec-RecordUuid OR Subty <> rec-Subty.

      " ---- delimit the record of this type that covers the new start date
      LOOP AT siblings INTO DATA(covering)
           WHERE Begda < rec-Begda AND Endda >= rec-Begda.
        DATA(prev_end) = CONV d( rec-Begda - 1 ).
        MODIFY ENTITIES OF zr_pa_employee IN LOCAL MODE
          ENTITY Address
            UPDATE FIELDS ( Endda )
            WITH VALUE #( ( %tky = covering-%tky  Endda = prev_end ) ).
        APPEND VALUE #( %tky  = rec-%tky
                        %path = VALUE #( employee-%is_draft = rec-%is_draft  employee-Pernr = rec-Pernr )
                        %msg  = new_message_with_text(
                                  severity = if_abap_behv_message=>severity-information
                                  text     = |Previous address delimited to { prev_end DATE = USER }| ) )
          TO reported-address.
        EXIT.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD checkMandatory.
  ENDMETHOD.


  METHOD checkTimeConstraint.

    DATA problem TYPE string.

    READ ENTITIES OF zr_pa_employee IN LOCAL MODE
      ENTITY Address
        FIELDS ( Pernr ) WITH CORRESPONDING #( keys )
      RESULT DATA(changed).

    LOOP AT changed INTO DATA(changed_rec)
         GROUP BY ( pernr    = changed_rec-Pernr
                    is_draft = changed_rec-%is_draft ) INTO DATA(emp).

      CLEAR problem.

      READ ENTITIES OF zr_pa_employee IN LOCAL MODE
        ENTITY Employee BY \_Address
          FIELDS ( Subty Begda Endda )
          WITH VALUE #( ( %is_draft = emp-is_draft
                          Pernr     = emp-pernr ) )
        RESULT DATA(records).
      SORT records BY Subty Begda.

      LOOP AT records INTO DATA(rec).
        DATA(idx) = sy-tabix.

        IF rec-Subty IS INITIAL.
          problem = |Address type missing ({ rec-Begda DATE = USER })|.
          EXIT.
        ENDIF.

        IF rec-Begda IS INITIAL OR rec-Endda < rec-Begda.
          problem = |Type { rec-Subty }: end before start ({ rec-Begda DATE = USER })|.
          EXIT.
        ENDIF.

        " compare with the previous record of the same type (gaps are allowed)
        IF idx > 1.
          DATA(prev) = records[ idx - 1 ].
          IF prev-Subty = rec-Subty.
            IF rec-Begda = prev-Begda.
              problem = |Type { rec-Subty }: two records start on { rec-Begda DATE = USER }|.
              EXIT.
            ELSEIF rec-Begda <= prev-Endda.
              problem = |Type { rec-Subty }: overlaps record ending { prev-Endda DATE = USER }|.
              EXIT.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDLOOP.

      LOOP AT GROUP emp INTO DATA(member).
        APPEND VALUE #( %tky        = member-%tky
                        %state_area = 'TIME_CONSTRAINT'
                        %path       = VALUE #( employee-%is_draft = member-%is_draft
                                               employee-Pernr     = member-Pernr ) )
          TO reported-address.

        IF problem IS NOT INITIAL.
          APPEND VALUE #( %tky = member-%tky ) TO failed-address.
          APPEND VALUE #( %tky           = member-%tky
                          %state_area    = 'TIME_CONSTRAINT'
                          %path          = VALUE #( employee-%is_draft = member-%is_draft
                                                    employee-Pernr     = member-Pernr )
                          %msg           = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = problem )
                          %element-Begda = if_abap_behv=>mk-on ) TO reported-address.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.