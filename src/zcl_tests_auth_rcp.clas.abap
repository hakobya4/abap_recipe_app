CLASS zcl_tests_auth_rcp DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_tests_auth_rcp IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA ls_test TYPE zrcp_recipe.

    ls_test-recipe_uuid         = cl_system_uuid=>create_uuid_x16_static( ).
    ls_test-user_uuid           = 'hakobyan.armenia@gmail.com'.
    ls_test-title               = 'DCL TEST - belongs to other user'.
    ls_test-servings             = 1.
    ls_test-servings_multiplier  = 1.
    ls_test-created_at           = utclong_current( ).
    ls_test-last_changed_at      = utclong_current( ).

    INSERT zrcp_recipe FROM @ls_test.
    COMMIT WORK.

    SELECT title, useruuid FROM zi_rcp_recipe INTO TABLE @DATA(lt_visible).

    LOOP AT lt_visible INTO DATA(ls_row).
      out->write( |{ ls_row-title } / { ls_row-useruuid }| ).
    ENDLOOP.

    out->write( |Total rows visible to current ADT user: { lines( lt_visible ) }| ).

*    DELETE FROM zrcp_recipe WHERE title = 'DCL TEST - belongs to other user'.
*    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
