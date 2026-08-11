CLASS zcl_auth_session_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " looks up the session and hands back who it belongs to -
    " empty means missing/expired/bad, caller just checks IS INITIAL
    CLASS-METHODS resolve_user
      IMPORTING iv_session_uuid     TYPE sysuuid_x16
      RETURNING VALUE(rv_user_uuid) TYPE sysuuid_x16.

ENDCLASS.


CLASS zcl_auth_session_check IMPLEMENTATION.

  METHOD resolve_user.
    IF iv_session_uuid IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE user_uuid, expires_at FROM zauth_sess
      WHERE session_uuid = @iv_session_uuid
      INTO @DATA(ls_sess).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ls_sess-expires_at < utclong_current( ).
      RETURN.
    ENDIF.

    rv_user_uuid = ls_sess-user_uuid.
  ENDMETHOD.

ENDCLASS.

