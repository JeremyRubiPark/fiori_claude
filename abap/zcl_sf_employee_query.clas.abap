"! Query provider for custom entity ZI_SF_EMPLOYEE.
"! Reads employees from SAP SuccessFactors OData V2 entity "User".
"!
"! c_use_mock = abap_true  : returns built-in sample data (no SF tenant needed)
"! c_use_mock = abap_false : calls SuccessFactors through the outbound service
"!                           ZSF_ODATA_REST of communication scenario ZSF_ODATA_SCENARIO
CLASS zcl_sf_employee_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    CONSTANTS:
      c_use_mock TYPE abap_bool VALUE abap_true,
      c_scenario TYPE c LENGTH 30 VALUE 'ZSF_ODATA_SCENARIO',
      c_service  TYPE c LENGTH 40 VALUE 'ZSF_ODATA_REST',
      c_uri_path TYPE string    VALUE '/odata/v2/User',
      c_select   TYPE string    VALUE 'userId,username,firstName,lastName,email,department,division,title,location,status'.

    TYPES:
      BEGIN OF ty_sf_user,
        userid     TYPE string,
        username   TYPE string,
        firstname  TYPE string,
        lastname   TYPE string,
        email      TYPE string,
        department TYPE string,
        division   TYPE string,
        title      TYPE string,
        location   TYPE string,
        status     TYPE string,
      END OF ty_sf_user,
      ty_sf_users TYPE STANDARD TABLE OF ty_sf_user WITH EMPTY KEY,
      BEGIN OF ty_d,
        results TYPE ty_sf_users,
      END OF ty_d,
      BEGIN OF ty_response,
        d TYPE ty_d,
      END OF ty_response,
      ty_employees TYPE STANDARD TABLE OF zi_sf_employee WITH EMPTY KEY.

    METHODS get_mock_users
      RETURNING VALUE(rt_users) TYPE ty_sf_users.

    METHODS call_successfactors
      IMPORTING iv_top    TYPE i
                iv_skip   TYPE i
                iv_filter TYPE string
                iv_order  TYPE string
      EXPORTING et_users  TYPE ty_sf_users
                ev_count  TYPE int8
      RAISING   cx_root.

    METHODS to_sf_field
      IMPORTING iv_element      TYPE string
      RETURNING VALUE(rv_field) TYPE string.

    METHODS to_employees
      IMPORTING it_users            TYPE ty_sf_users
      RETURNING VALUE(rt_employees) TYPE ty_employees.
ENDCLASS.


CLASS zcl_sf_employee_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_users TYPE ty_sf_users.
    DATA lv_count TYPE int8.

    TRY.
        " ---- paging -------------------------------------------------------
        DATA(lv_top)  = CONV i( io_request->get_paging( )->get_page_size( ) ).
        DATA(lv_skip) = CONV i( io_request->get_paging( )->get_offset( ) ).
        IF lv_top <= 0. " unlimited page size
          lv_top = 100.
        ENDIF.

        " ---- filter (only single EQ values are pushed down to SF) ----------
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
        DATA lr_userid TYPE RANGE OF zi_sf_employee-userid.
        DATA lr_dept   TYPE RANGE OF zi_sf_employee-department.
        LOOP AT lt_ranges INTO DATA(ls_range).
          CASE to_upper( ls_range-name ).
            WHEN 'USERID'.
              lr_userid = CORRESPONDING #( ls_range-range ).
            WHEN 'DEPARTMENT'.
              lr_dept = CORRESPONDING #( ls_range-range ).
          ENDCASE.
        ENDLOOP.

        DATA(lv_filter) = ``.
        IF lines( lr_userid ) = 1 AND lr_userid[ 1 ]-sign = 'I' AND lr_userid[ 1 ]-option = 'EQ'.
          lv_filter = |userId eq '{ lr_userid[ 1 ]-low }'|.
        ENDIF.
        IF lines( lr_dept ) = 1 AND lr_dept[ 1 ]-sign = 'I' AND lr_dept[ 1 ]-option = 'EQ'.
          lv_filter = COND #( WHEN lv_filter IS INITIAL
                              THEN |department eq '{ lr_dept[ 1 ]-low }'|
                              ELSE |{ lv_filter } and department eq '{ lr_dept[ 1 ]-low }'| ).
        ENDIF.

        " ---- sorting ------------------------------------------------------
        DATA(lt_sort) = io_request->get_sort_elements( ).
        DATA(lv_order) = ``.
        LOOP AT lt_sort INTO DATA(ls_sort).
          DATA(lv_sf_field) = to_sf_field( CONV #( ls_sort-element_name ) ).
          IF lv_sf_field IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_order = COND #( WHEN lv_order IS INITIAL
                             THEN |{ lv_sf_field } { COND string( WHEN ls_sort-descending = abap_true THEN 'desc' ELSE 'asc' ) }|
                             ELSE |{ lv_order },{ lv_sf_field } { COND string( WHEN ls_sort-descending = abap_true THEN 'desc' ELSE 'asc' ) }| ).
        ENDLOOP.

        " ---- data ---------------------------------------------------------
        DATA lt_employees TYPE ty_employees.

        IF c_use_mock = abap_true.
          lt_employees = to_employees( get_mock_users( ) ).

          DELETE lt_employees WHERE NOT ( userid IN lr_userid AND department IN lr_dept ).

          IF lt_sort IS NOT INITIAL.
            DATA lt_sortorder TYPE abap_sortorder_tab.
            lt_sortorder = VALUE #( FOR s IN lt_sort
                                    ( name = s-element_name descending = s-descending ) ).
            SORT lt_employees BY (lt_sortorder).
          ENDIF.

          lv_count = lines( lt_employees ).

          " manual paging
          IF lv_skip > 0 AND lines( lt_employees ) > 0.
            DATA(lv_del_to) = nmin( val1 = lv_skip val2 = lines( lt_employees ) ).
            DELETE lt_employees FROM 1 TO lv_del_to.
          ENDIF.
          IF lines( lt_employees ) > lv_top.
            DATA(lv_del_from) = lv_top + 1.
            DELETE lt_employees FROM lv_del_from.
          ENDIF.
        ELSE.
          call_successfactors(
            EXPORTING iv_top    = lv_top
                      iv_skip   = lv_skip
                      iv_filter = lv_filter
                      iv_order  = lv_order
            IMPORTING et_users  = lt_users
                      ev_count  = lv_count ).
          lt_employees = to_employees( lt_users ).
        ENDIF.

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lv_count ).
        ENDIF.
        IF io_request->is_data_requested( ).
          io_response->set_data( lt_employees ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        RAISE EXCEPTION NEW zcx_sf_employee_error( previous = lx_root ).
    ENDTRY.
  ENDMETHOD.


  METHOD call_successfactors.
    DATA ls_response TYPE ty_response.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = c_scenario
                             service_id    = c_service ).
    DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    TRY.
        DATA(lo_request) = lo_client->get_http_request( ).

        DATA(lv_query) = |$format=json&$inlinecount=allpages&$select={ c_select }&$top={ iv_top }&$skip={ iv_skip }|.
        IF iv_filter IS NOT INITIAL.
          lv_query = |{ lv_query }&$filter={ escape( val = iv_filter format = cl_abap_format=>e_uri_full ) }|.
        ENDIF.
        IF iv_order IS NOT INITIAL.
          lv_query = |{ lv_query }&$orderby={ escape( val = iv_order format = cl_abap_format=>e_uri_full ) }|.
        ENDIF.

        lo_request->set_uri_path( i_uri_path = c_uri_path ).
        lo_request->set_query( i_query = lv_query ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(lv_status)   = lo_response->get_status( )-code.
        DATA(lv_json)     = lo_response->get_text( ).

        IF lv_status <> 200.
          RAISE EXCEPTION TYPE zcx_sf_employee_error.
        ENDIF.

        /ui2/cl_json=>deserialize(
          EXPORTING json        = lv_json
                    pretty_name = /ui2/cl_json=>pretty_mode-camel_case
          CHANGING  data        = ls_response ).
        et_users = ls_response-d-results.

        " OData V2 inline count: "__count":"123"
        FIND REGEX '"__count"\s*:\s*"?(\d+)' IN lv_json SUBMATCHES DATA(lv_cnt).
        IF sy-subrc = 0.
          ev_count = CONV int8( lv_cnt ).
        ELSE.
          ev_count = lines( et_users ).
        ENDIF.

      CLEANUP.
        lo_client->close( ).
    ENDTRY.
    lo_client->close( ).
  ENDMETHOD.


  METHOD to_sf_field.
    rv_field = SWITCH #( to_upper( iv_element )
                 WHEN 'USERID'     THEN 'userId'
                 WHEN 'FULLNAME'   THEN 'lastName'
                 WHEN 'FIRSTNAME'  THEN 'firstName'
                 WHEN 'LASTNAME'   THEN 'lastName'
                 WHEN 'EMAIL'      THEN 'email'
                 WHEN 'DEPARTMENT' THEN 'department'
                 WHEN 'DIVISION'   THEN 'division'
                 WHEN 'JOBTITLE'   THEN 'title'
                 WHEN 'LOCATION'   THEN 'location'
                 WHEN 'STATUS'     THEN 'status'
                 ELSE `` ).
  ENDMETHOD.


  METHOD to_employees.
    rt_employees = VALUE #(
      FOR u IN it_users
      ( userid     = u-userid
        fullname   = condense( |{ u-firstname } { u-lastname }| )
        firstname  = u-firstname
        lastname   = u-lastname
        email      = u-email
        department = u-department
        division   = u-division
        jobtitle   = u-title
        location   = u-location
        status     = u-status ) ).
  ENDMETHOD.


  METHOD get_mock_users.
    rt_users = VALUE #(
      ( userid = '100001' username = 'hgdong'   firstname = 'Gildong' lastname = 'Hong'
        email = 'gildong.hong@example.com' department = 'Human Resources' division = 'Corporate'
        title = 'HR Manager'        location = 'Seoul'  status = 'active' )
      ( userid = '100002' username = 'cskim'    firstname = 'Chulsoo' lastname = 'Kim'
        email = 'chulsoo.kim@example.com'  department = 'IT'              division = 'Technology'
        title = 'Software Engineer' location = 'Seoul'  status = 'active' )
      ( userid = '100003' username = 'yhlee'    firstname = 'Younghee' lastname = 'Lee'
        email = 'younghee.lee@example.com' department = 'Finance'         division = 'Corporate'
        title = 'Accountant'        location = 'Busan'  status = 'active' )
      ( userid = '100004' username = 'mspark'   firstname = 'Minsu'   lastname = 'Park'
        email = 'minsu.park@example.com'   department = 'IT'              division = 'Technology'
        title = 'IT Architect'      location = 'Seoul'  status = 'active' )
      ( userid = '100005' username = 'jychoi'   firstname = 'Jiyoung' lastname = 'Choi'
        email = 'jiyoung.choi@example.com' department = 'Sales'           division = 'Commercial'
        title = 'Sales Lead'        location = 'Daegu'  status = 'active' )
      ( userid = '100006' username = 'shjung'   firstname = 'Sunghyun' lastname = 'Jung'
        email = 'sunghyun.jung@example.com' department = 'Sales'          division = 'Commercial'
        title = 'Account Executive' location = 'Seoul'  status = 'inactive' )
      ( userid = '100007' username = 'eykang'   firstname = 'Eunyoung' lastname = 'Kang'
        email = 'eunyoung.kang@example.com' department = 'Human Resources' division = 'Corporate'
        title = 'Recruiter'         location = 'Seoul'  status = 'active' )
      ( userid = '100008' username = 'dhyoon'   firstname = 'Donghyun' lastname = 'Yoon'
        email = 'donghyun.yoon@example.com' department = 'IT'             division = 'Technology'
        title = 'DevOps Engineer'   location = 'Incheon' status = 'active' ) ).
  ENDMETHOD.

ENDCLASS.
