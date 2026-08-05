CLASS lhc_Session DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Session RESULT result.

    METHODS logout FOR MODIFY
      IMPORTING keys FOR ACTION Session~logout.

ENDCLASS.

CLASS lhc_Session IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD logout.

    MODIFY ENTITIES OF zi_auth_sess IN LOCAL MODE
      ENTITY Session
        DELETE FROM VALUE #( FOR <key> IN keys ( %tky = <key>-%tky ) )
      FAILED   DATA(failed_delete)
      REPORTED DATA(reported_delete).

    failed-Session   = CORRESPONDING #( BASE ( failed-Session ) failed_delete-Session ).
    reported-Session = CORRESPONDING #( BASE ( reported-Session ) reported_delete-Session ).

  ENDMETHOD.

ENDCLASS.
