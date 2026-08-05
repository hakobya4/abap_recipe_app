CLASS zcl_auth_password_hash DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS c_default_iterations TYPE i VALUE 10000.

    CLASS-METHODS generate_salt
      RETURNING VALUE(rv_salt) TYPE string
      RAISING   cx_uuid_error.


    CLASS-METHODS hash
      IMPORTING
                iv_password    TYPE string
                iv_salt        TYPE string
                iv_iterations  TYPE i
      RETURNING VALUE(rv_hash) TYPE string
      RAISING   cx_abap_message_digest.


ENDCLASS.


CLASS zcl_auth_password_hash IMPLEMENTATION.

  METHOD generate_salt.
    rv_salt = cl_system_uuid=>create_uuid_c32_static( ).
  ENDMETHOD.

  METHOD hash.
    DATA(lv_current) = iv_salt && iv_password.

    DO iv_iterations TIMES.
      cl_abap_message_digest=>calculate_hash_for_char(
        EXPORTING
          if_algorithm  = 'SHA-256'
          if_data       = lv_current && iv_salt
        IMPORTING
          ef_hashstring = lv_current ).
    ENDDO.

    rv_hash = lv_current.
  ENDMETHOD.

ENDCLASS.
