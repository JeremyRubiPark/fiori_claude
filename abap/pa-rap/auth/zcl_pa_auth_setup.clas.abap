CLASS zcl_pa_auth_setup DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_pa_auth_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Sets the PA authorization profile of the current user (run with F9 in ADT).
    " Change c_profile and run again to switch:
    "   MAINTAIN_ALL   maintain (02) all personnel areas
    "   DISPLAY_ONLY   display (03) only: no Edit, no PA40 actions
    "   MAINTAIN_1000  maintain personnel area 1000 only, display the rest
    " ZPA_AUTH plays the role of the SAP HR authorization object P_ORGIN
    " (personnel area + activity). In a productive system this would be a custom
    " authorization object assigned through an IAM app, business catalog and business role.
    CONSTANTS c_profile TYPE string VALUE `MAINTAIN_ALL`.

    DATA entries TYPE STANDARD TABLE OF zpa_auth WITH EMPTY KEY.
    DATA(user) = CONV zpa_auth-uname( cl_abap_context_info=>get_user_technical_name( ) ).

    CASE c_profile.
      WHEN `MAINTAIN_ALL`.
        entries = VALUE #( ( uname = user  werks = '*'     actvt = '02' ) ).
      WHEN `DISPLAY_ONLY`.
        entries = VALUE #( ( uname = user  werks = '*'     actvt = '03' ) ).
      WHEN `MAINTAIN_1000`.
        entries = VALUE #( ( uname = user  werks = '1000'  actvt = '02' )
                           ( uname = user  werks = '*'     actvt = '03' ) ).
      WHEN OTHERS.
        out->write( |Unknown profile { c_profile }| ).
        RETURN.
    ENDCASE.

    DELETE FROM zpa_auth WHERE uname = @user.
    INSERT zpa_auth FROM TABLE @entries.
    DATA(inserted) = sy-dbcnt.
    COMMIT WORK.

    SELECT * FROM zpa_auth WHERE uname = @user INTO TABLE @DATA(saved).

    out->write( |Profile { c_profile }: { inserted } row(s) inserted for user { user }| ).
    out->write( |Rows now in ZPA_AUTH for this user:| ).
    out->write( saved ).
  ENDMETHOD.

ENDCLASS.
