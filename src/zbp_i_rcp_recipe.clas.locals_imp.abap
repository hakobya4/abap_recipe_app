CLASS lhc_Recipe DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Recipe RESULT result.

    METHODS prepare_ingredients FOR DETERMINE ON SAVE
      IMPORTING keys FOR Recipe~prepare_ingredients.

    METHODS import_from_url FOR MODIFY
      IMPORTING keys FOR ACTION Recipe~importFromUrl RESULT result.

    METHODS parse_ingredient_line
      IMPORTING iv_line            TYPE string
      EXPORTING ev_quantity        TYPE decfloat16
                ev_unit_code       TYPE string
                ev_ingredient_name TYPE string.

    METHODS extract_json_object
      IMPORTING iv_text          TYPE string
                iv_marker        TYPE string
      RETURNING VALUE(rv_object) TYPE string.

    METHODS parse_minutes
      IMPORTING iv_duration       TYPE string
      RETURNING VALUE(rv_minutes) TYPE i.

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

      " convert to the base unit, then to whatever unit was picked
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

  METHOD import_from_url.

    TYPES: BEGIN OF ty_ld_step,
             text TYPE string,
           END OF ty_ld_step.

    TYPES: BEGIN OF ty_ld_recipe,
             name                TYPE string,
             recipe_yield        TYPE string_table,
             recipe_ingredient   TYPE string_table,
             recipe_instructions TYPE STANDARD TABLE OF ty_ld_step WITH EMPTY KEY,
             prep_time           TYPE string,
             cook_time           TYPE string,
             total_time          TYPE string,
           END OF ty_ld_recipe.

    " fallback for sites that give yield/instructions as plain strings
    TYPES: BEGIN OF ty_ld_recipe_flat,
             recipe_yield        TYPE string,
             recipe_instructions TYPE string_table,
           END OF ty_ld_recipe_flat.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      DATA(lv_url)    = <key>-%param-Url.
      DATA(lv_pasted) = <key>-%param-JsonLd.

      IF lv_url IS INITIAL AND lv_pasted IS INITIAL.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-Recipe.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'A URL is required.' )
        ) TO reported-Recipe.
        CONTINUE.
      ENDIF.

      DATA(lv_html) = ``.

      IF lv_pasted IS NOT INITIAL.
        " skip the fetch entirely - use what was pasted as-is
        lv_html = lv_pasted.
      ELSE.
        TRY.
            DATA(lo_destination) = cl_http_destination_provider=>create_by_url( lv_url ).
            DATA(lo_http_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

            lo_http_client->get_http_request( )->set_header_field(
              i_name  = 'User-Agent'
              i_value = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                     && '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36' ).


            DATA(lo_response) = lo_http_client->execute( if_web_http_client=>get ).
            lv_html = lo_response->get_text( ).


          CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_http_error).
            APPEND VALUE #( %cid = <key>-%cid ) TO failed-Recipe.
            APPEND VALUE #(
              %cid = <key>-%cid
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Could not fetch that URL: { lx_http_error->get_text( ) }| )
            ) TO reported-Recipe.
            CONTINUE.
        ENDTRY.
      ENDIF.

      " a page can have several JSON-LD blocks - find the recipe one
      DATA(lv_recipe_json) = ``.


      " if nothing was pasted with a <script> wrapper, try the raw
      " pasted text directly - it might just be the bare JSON already
      IF lv_recipe_json IS INITIAL AND lv_pasted IS NOT INITIAL AND lv_pasted CS '"Recipe"'.
        lv_recipe_json = lv_pasted.
      ENDIF.

      FIND ALL OCCURRENCES OF PCRE
        '<script[^>]*type\s*=\s*"application/ld\+json"[^>]*>(.*?)</script>'
        IN lv_html RESULTS DATA(lt_script_matches) IGNORING CASE.

      LOOP AT lt_script_matches INTO DATA(ls_match).
        DATA(lv_offset) = ls_match-submatches[ 1 ]-offset.
        DATA(lv_length) = ls_match-submatches[ 1 ]-length.
        DATA(lv_block)  = lv_html+lv_offset(lv_length).
        IF lv_block CS '"Recipe"'.
          lv_recipe_json = lv_block.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_recipe_json IS INITIAL.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-Recipe.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'No recipe data (schema.org JSON-LD) found on that page.' )
        ) TO reported-Recipe.
        CONTINUE.
      ENDIF.

      DATA(ls_ld_recipe) = VALUE ty_ld_recipe( ).

      /ui2/cl_json=>deserialize(
        EXPORTING json        = lv_recipe_json
                  pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        CHANGING  data        = ls_ld_recipe ).

      " some sites wrap everything in "@graph" - dig the recipe out if so
      IF ls_ld_recipe-name IS INITIAL.
        DATA(lv_isolated) = extract_json_object(
          iv_text   = lv_recipe_json
          iv_marker = '"@type":"Recipe"' ).

        IF lv_isolated IS INITIAL.
          lv_isolated = extract_json_object(
            iv_text   = lv_recipe_json
            iv_marker = '"@type": "Recipe"' ).
        ENDIF.

        IF lv_isolated IS NOT INITIAL.
          lv_recipe_json = lv_isolated.
          CLEAR ls_ld_recipe.
          /ui2/cl_json=>deserialize(
            EXPORTING json        = lv_recipe_json
                      pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING  data        = ls_ld_recipe ).
        ENDIF.
      ENDIF.

      DATA(ls_ld_recipe_flat) = VALUE ty_ld_recipe_flat( ).

      IF ls_ld_recipe-recipe_instructions IS INITIAL OR ls_ld_recipe-recipe_yield IS INITIAL.
        /ui2/cl_json=>deserialize(
          EXPORTING json        = lv_recipe_json
                    pretty_name = /ui2/cl_json=>pretty_mode-camel_case
          CHANGING  data        = ls_ld_recipe_flat ).
      ENDIF.

      DATA(lv_servings) = 0.
      DATA(lv_yield_text) = COND string( WHEN ls_ld_recipe-recipe_yield IS NOT INITIAL
                                          THEN ls_ld_recipe-recipe_yield[ 1 ]
                                          ELSE ls_ld_recipe_flat-recipe_yield ).
      FIND PCRE '(\d+)' IN lv_yield_text SUBMATCHES DATA(lv_yield_digits).
      IF sy-subrc = 0.
        lv_servings = lv_yield_digits.
      ENDIF.

      " stage ingredients/steps in plain structs first, shape them later
      TYPES: BEGIN OF ty_parsed_ingredient,
               sort_order      TYPE i,
               ingredient_name TYPE string,
               quantity        TYPE decfloat34,
               unit_code       TYPE string,
             END OF ty_parsed_ingredient.
      TYPES: BEGIN OF ty_parsed_step,
               step_number TYPE i,
               instruction TYPE string,
             END OF ty_parsed_step.

      DATA(lv_sort) = 10.
      DATA lt_parsed_ingredients TYPE STANDARD TABLE OF ty_parsed_ingredient WITH EMPTY KEY.

      LOOP AT ls_ld_recipe-recipe_ingredient INTO DATA(lv_ingredient_line).
        parse_ingredient_line(
          EXPORTING iv_line            = lv_ingredient_line
          IMPORTING ev_quantity        = DATA(lv_qty)
                    ev_unit_code       = DATA(lv_unit)
                    ev_ingredient_name = DATA(lv_name) ).

        APPEND VALUE #(
          sort_order      = lv_sort
          ingredient_name = lv_name
          quantity        = lv_qty
          unit_code       = lv_unit
        ) TO lt_parsed_ingredients.

        lv_sort = lv_sort + 10.
      ENDLOOP.

      DATA(lv_step_no) = 1.
      DATA lt_parsed_steps TYPE STANDARD TABLE OF ty_parsed_step WITH EMPTY KEY.

      IF ls_ld_recipe-recipe_instructions IS NOT INITIAL.
        LOOP AT ls_ld_recipe-recipe_instructions INTO DATA(ls_step).
          APPEND VALUE #( step_number = lv_step_no instruction = ls_step-text ) TO lt_parsed_steps.
          lv_step_no = lv_step_no + 1.
        ENDLOOP.
      ELSEIF ls_ld_recipe_flat-recipe_instructions IS NOT INITIAL.
        LOOP AT ls_ld_recipe_flat-recipe_instructions INTO DATA(lv_step_text).
          APPEND VALUE #( step_number = lv_step_no instruction = lv_step_text ) TO lt_parsed_steps.
          lv_step_no = lv_step_no + 1.
        ENDLOOP.
      ENDIF.

            " if cook time is missing but prep + total are there, back it out
      DATA(lv_prep_minutes) = parse_minutes( ls_ld_recipe-prep_time ).
      DATA(lv_cook_minutes) = parse_minutes( ls_ld_recipe-cook_time ).

      IF lv_cook_minutes = 0 AND ls_ld_recipe-total_time IS NOT INITIAL.
        DATA(lv_total_minutes) = parse_minutes( ls_ld_recipe-total_time ).
        IF lv_total_minutes > lv_prep_minutes.
          lv_cook_minutes = lv_total_minutes - lv_prep_minutes.
        ENDIF.
      ENDIF.


      " create the recipe first, no children yet
      DATA lt_recipe_create TYPE TABLE FOR CREATE zi_rcp_recipe\\Recipe.

      APPEND VALUE #(
        %cid               = <key>-%cid
        Title              = COND #( WHEN ls_ld_recipe-name IS NOT INITIAL
                                      THEN ls_ld_recipe-name ELSE 'Imported Recipe' )
        Description        = |Imported from { lv_url }|
        Servings           = lv_servings
        ServingsMultiplier = 1
        PrepMinutes        = lv_prep_minutes
        CookMinutes        = lv_cook_minutes
      ) TO lt_recipe_create.

      MODIFY ENTITIES OF zi_rcp_recipe IN LOCAL MODE
        ENTITY Recipe
          CREATE FIELDS ( Title Description Servings ServingsMultiplier PrepMinutes CookMinutes UserUuid )
          WITH lt_recipe_create
        MAPPED   DATA(mapped_create)
        FAILED   DATA(failed_create)
        REPORTED DATA(reported_create).

      failed-Recipe   = CORRESPONDING #( BASE ( failed-Recipe ) failed_create-Recipe ).
      reported-Recipe = CORRESPONDING #( BASE ( reported-Recipe ) reported_create-Recipe ).

      READ TABLE mapped_create-recipe INTO DATA(ls_recipe_mapped) INDEX 1.
      CHECK sy-subrc = 0.

      " add the ingredients as children of that recipe
      IF lt_parsed_ingredients IS NOT INITIAL.
        MODIFY ENTITIES OF zi_rcp_recipe IN LOCAL MODE
          ENTITY Recipe
            CREATE BY \_Ingredient
              FIELDS ( SortOrder IngredientName Quantity UnitCode )
              WITH VALUE #( (
                %tky    = CORRESPONDING #( ls_recipe_mapped-%pky )
                %target = VALUE #( FOR <ing> IN lt_parsed_ingredients (
                            %cid           = |ING{ <ing>-sort_order }|
                            SortOrder      = <ing>-sort_order
                            IngredientName = <ing>-ingredient_name
                            Quantity       = <ing>-quantity
                            UnitCode       = <ing>-unit_code
                          ) )
              ) )
          FAILED   DATA(failed_ing)
          REPORTED DATA(reported_ing).

        failed-Ingredient   = CORRESPONDING #( BASE ( failed-Ingredient ) failed_ing-ingredient ).
        reported-Ingredient = CORRESPONDING #( BASE ( reported-Ingredient ) reported_ing-ingredient ).
      ENDIF.

      " same for the steps
      IF lt_parsed_steps IS NOT INITIAL.
        MODIFY ENTITIES OF zi_rcp_recipe IN LOCAL MODE
          ENTITY Recipe
            CREATE BY \_Step
              FIELDS ( StepNumber Instruction )
              WITH VALUE #( (
                %tky    = CORRESPONDING #( ls_recipe_mapped-%pky )
                %target = VALUE #( FOR <stp> IN lt_parsed_steps (
                            %cid        = |STP{ <stp>-step_number }|
                            StepNumber  = <stp>-step_number
                            Instruction = <stp>-instruction
                          ) )
              ) )
          FAILED   DATA(failed_step)
          REPORTED DATA(reported_step).

        failed-Step   = CORRESPONDING #( BASE ( failed-Step ) failed_step-step ).
        reported-Step = CORRESPONDING #( BASE ( reported-Step ) reported_step-step ).
      ENDIF.

      " read the finished recipe back and return it
      READ ENTITIES OF zi_rcp_recipe IN LOCAL MODE
        ENTITY Recipe ALL FIELDS
          WITH VALUE #( ( %tky = CORRESPONDING #( ls_recipe_mapped-%pky ) ) )
        RESULT DATA(created_recipes).

      READ TABLE created_recipes INTO DATA(ls_created) INDEX 1.
      APPEND VALUE #(
        %cid   = <key>-%cid
        %param = COND #( WHEN sy-subrc = 0
                          THEN CORRESPONDING #( ls_created )
                          ELSE VALUE #( RecipeUuid = ls_recipe_mapped-%pky-RecipeUuid ) )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD parse_ingredient_line.

    DATA(lv_remaining) = iv_line.
    CONDENSE lv_remaining.

    ev_quantity = 0.
    CLEAR ev_unit_code.

    " grab the leading amount: "1 1/2", "1/2", "2", "2.5"
    FIND PCRE '^(\d+\s+\d+/\d+|\d+/\d+|\d+(\.\d+)?)\s*'
      IN lv_remaining SUBMATCHES DATA(lv_qty_text) DATA(lv_dummy).

    IF sy-subrc = 0 AND lv_qty_text IS NOT INITIAL.
      DATA(lv_qty_len) = strlen( lv_qty_text ).
      DATA(lv_rest)    = lv_remaining+lv_qty_len.
      CONDENSE lv_qty_text.

      IF lv_qty_text CS '/'.
        SPLIT lv_qty_text AT space INTO TABLE DATA(lt_parts).
        DATA(lv_whole) = COND decfloat34( WHEN lines( lt_parts ) = 2 THEN lt_parts[ 1 ] ELSE 0 ).
        DATA(lv_frac)  = COND string(     WHEN lines( lt_parts ) = 2 THEN lt_parts[ 2 ] ELSE lt_parts[ 1 ] ).
        SPLIT lv_frac AT '/' INTO DATA(lv_num) DATA(lv_den).
        ev_quantity = lv_whole + ( CONV decfloat34( lv_num ) / CONV decfloat34( lv_den ) ).
      ELSE.
        ev_quantity = CONV decfloat34( lv_qty_text ).
      ENDIF.

      lv_remaining = lv_rest.
      SHIFT lv_remaining LEFT DELETING LEADING space.
    ENDIF.

    " grab the leading unit word, match it to our known unit codes
    FIND PCRE '^([[:alpha:]]+)\.?\s+' IN lv_remaining SUBMATCHES DATA(lv_unit_word).

    IF sy-subrc = 0 AND lv_unit_word IS NOT INITIAL.
      DATA(lv_unit_upper) = to_upper( lv_unit_word ).

      DATA(lv_code) = SWITCH string( lv_unit_upper
        WHEN 'CUP' OR 'CUPS'                              THEN 'CUP'
        WHEN 'TBSP' OR 'TABLESPOON' OR 'TABLESPOONS'       THEN 'TBSP'
        WHEN 'TSP' OR 'TEASPOON' OR 'TEASPOONS'            THEN 'TSP'
        WHEN 'ML' OR 'MILLILITER' OR 'MILLILITERS'
          OR 'MILLILITRE' OR 'MILLILITRES'                 THEN 'ML'
        WHEN 'L' OR 'LITER' OR 'LITERS' OR 'LITRE' OR 'LITRES' THEN 'L'
        WHEN 'G' OR 'GRAM' OR 'GRAMS'                      THEN 'G'
        WHEN 'KG' OR 'KILOGRAM' OR 'KILOGRAMS'             THEN 'KG'
        WHEN 'OZ' OR 'OUNCE' OR 'OUNCES'                   THEN 'OZ'
        WHEN 'LB' OR 'LBS' OR 'POUND' OR 'POUNDS'          THEN 'LB'
        ELSE ''
      ).

      IF lv_code IS NOT INITIAL.
        ev_unit_code = lv_code.
        DATA(lv_unit_len) = strlen( lv_unit_word ).
        lv_remaining = lv_remaining+lv_unit_len.
        SHIFT lv_remaining LEFT DELETING LEADING space.
      ENDIF.
    ENDIF.

    ev_ingredient_name = lv_remaining.
    CONDENSE ev_ingredient_name.

  ENDMETHOD.

  METHOD extract_json_object.

    " pull the {...} that contains iv_marker out of a bigger JSON blob
    FIND iv_marker IN iv_text MATCH OFFSET DATA(lv_marker_offset).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_stack TYPE TABLE OF i.
    DATA(lv_len) = strlen( iv_text ).
    DATA(lv_pos) = 0.

    WHILE lv_pos < lv_len AND lv_pos <= lv_marker_offset.
      DATA(lv_ch) = iv_text+lv_pos(1).
      IF lv_ch = '{'.
        APPEND lv_pos TO lt_stack.
      ELSEIF lv_ch = '}' AND lt_stack IS NOT INITIAL.
        DELETE lt_stack INDEX lines( lt_stack ).
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lt_stack IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_start) = lt_stack[ lines( lt_stack ) ].
    DATA(lv_depth) = 0.
    DATA(lv_end)   = -1.
    lv_pos = lv_start.

    WHILE lv_pos < lv_len.
      DATA(lv_ch2) = iv_text+lv_pos(1).
      IF lv_ch2 = '{'.
        lv_depth = lv_depth + 1.
      ELSEIF lv_ch2 = '}'.
        lv_depth = lv_depth - 1.
        IF lv_depth = 0.
          lv_end = lv_pos.
          EXIT.
        ENDIF.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    CHECK lv_end >= lv_start.
    DATA(lv_obj_len) = lv_end - lv_start + 1.
    rv_object = iv_text+lv_start(lv_obj_len).

  ENDMETHOD.

  METHOD parse_minutes.

    rv_minutes = 0.
    CHECK iv_duration IS NOT INITIAL.

    FIND PCRE 'PT(?:(\d+)H)?(?:(\d+)M)?' IN iv_duration SUBMATCHES DATA(lv_hours) DATA(lv_mins).
    CHECK sy-subrc = 0.

    rv_minutes = COND i( WHEN lv_hours IS NOT INITIAL THEN lv_hours * 60 ELSE 0 )
               + COND i( WHEN lv_mins  IS NOT INITIAL THEN lv_mins       ELSE 0 ).

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Ingredient DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Ingredient RESULT result.

    METHODS toggleobtained FOR MODIFY
      IMPORTING keys FOR ACTION Ingredient~toggleObtained RESULT result.

ENDCLASS.

CLASS lhc_Ingredient IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

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

ENDCLASS.
