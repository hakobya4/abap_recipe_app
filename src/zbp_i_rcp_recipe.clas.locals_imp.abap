CLASS lhc_Recipe DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Recipe RESULT result.

    METHODS prepare_ingredients FOR DETERMINE ON SAVE
      IMPORTING keys FOR Recipe~prepare_ingredients.

ENDCLASS.

CLASS lhc_Recipe IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD prepare_ingredients.

    READ ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Recipe
        FIELDS ( ServingsMultiplier )
        WITH CORRESPONDING #( keys )
      RESULT DATA(recipes).

    READ ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Recipe BY \_Ingredient
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(ingredients).

    CHECK ingredients IS NOT INITIAL.

    SELECT unit_code, category, factor_to_base
      FROM zrcp_uom
      INTO TABLE @DATA(lt_uom).

    DATA lt_update      TYPE TABLE FOR UPDATE zi_rcp_recipe\\Ingredient.
    DATA ls_source_uom   LIKE LINE OF lt_uom.
    DATA ls_target_uom   LIKE LINE OF lt_uom.

    LOOP AT ingredients INTO DATA(ls_ingredient).

      READ TABLE recipes WITH KEY RecipeUuid = ls_ingredient-RecipeUuid
        INTO DATA(ls_recipe).
      DATA(lv_multiplier) = COND decfloat34( WHEN sy-subrc = 0 THEN ls_recipe-ServingsMultiplier ELSE 1 ).

      DATA(lv_scaled) = ls_ingredient-Quantity * lv_multiplier.

      CLEAR: ls_source_uom, ls_target_uom.
      DATA(lv_converted) = CONV decfloat34( 0 ).

      " Reduce the scaled quantity to its own category's base unit
      " (ml for volume, g for weight), then re-expand into whatever
      " target unit the user picked - crossing categories only when a
      " Density was captured for this ingredient.
      READ TABLE lt_uom WITH KEY unit_code = ls_ingredient-UnitCode INTO ls_source_uom.

      IF sy-subrc = 0 AND ls_ingredient-TargetUnitCode IS NOT INITIAL.
        READ TABLE lt_uom WITH KEY unit_code = ls_ingredient-TargetUnitCode INTO ls_target_uom.

        IF sy-subrc = 0.
          DATA(lv_base_qty) = lv_scaled * ls_source_uom-factor_to_base.

          IF ls_source_uom-category = ls_target_uom-category.
            lv_converted = lv_base_qty / ls_target_uom-factor_to_base.
          ELSEIF ls_source_uom-category = 'VOLUME' AND ls_target_uom-category = 'WEIGHT'
                 AND ls_ingredient-Density IS NOT INITIAL.
            lv_converted = ( lv_base_qty * ls_ingredient-Density ) / ls_target_uom-factor_to_base.
          ELSEIF ls_source_uom-category = 'WEIGHT' AND ls_target_uom-category = 'VOLUME'
                 AND ls_ingredient-Density IS NOT INITIAL AND ls_ingredient-Density <> 0.
            lv_converted = ( lv_base_qty / ls_ingredient-Density ) / ls_target_uom-factor_to_base.
          ENDIF.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        %tky                       = ls_ingredient-%tky
        ScaledQuantity              = lv_scaled
        ConvertedQuantity           = lv_converted
        %control-ScaledQuantity    = if_abap_behv=>mk-on
        %control-ConvertedQuantity = if_abap_behv=>mk-on
      ) TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Ingredient
        UPDATE FIELDS ( ScaledQuantity ConvertedQuantity )
        WITH lt_update
      FAILED   DATA(failed_update)
      REPORTED DATA(reported_update).

    reported-Ingredient = CORRESPONDING #( BASE ( reported-Ingredient ) reported_update-Ingredient ).

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Ingredient DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS toggleobtained FOR MODIFY
      IMPORTING keys FOR ACTION Ingredient~toggleObtained RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Ingredient RESULT result.

ENDCLASS.

CLASS lhc_Ingredient IMPLEMENTATION.

  METHOD toggleobtained.

    READ ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Ingredient
        FIELDS ( IsObtained )
        WITH CORRESPONDING #( keys )
      RESULT DATA(current).

    DATA lt_update TYPE TABLE FOR UPDATE zi_rcp_recipe\\Ingredient.

    LOOP AT current INTO DATA(ls_current).
      APPEND VALUE #(
        %tky                 = ls_current-%tky
        IsObtained            = xsdbool( ls_current-IsObtained = abap_false )
        %control-IsObtained  = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Ingredient
        UPDATE FIELDS ( IsObtained )
        WITH lt_update
      FAILED   DATA(failed_update)
      REPORTED DATA(reported_update).

    failed-Ingredient   = CORRESPONDING #( BASE ( failed-Ingredient ) failed_update-Ingredient ).
    reported-Ingredient = CORRESPONDING #( BASE ( reported-Ingredient ) reported_update-Ingredient ).

    READ ENTITIES OF zi_rcp_recipe IN LOCAL MODE
      ENTITY Ingredient
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR ls_u IN updated (
      %tky   = ls_u-%tky
      %param = ls_u
    ) ).

  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

ENDCLASS.
