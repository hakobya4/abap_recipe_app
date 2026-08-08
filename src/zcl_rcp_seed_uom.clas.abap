CLASS zcl_rcp_seed_uom DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_rcp_seed_uom IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    MODIFY zrcp_uom FROM TABLE @( VALUE #(
      ( unit_code = 'CUP'  unit_text = 'Cup'        category = 'VOLUME' factor_to_base = '236.588' )
      ( unit_code = 'TBSP' unit_text = 'Tablespoon' category = 'VOLUME' factor_to_base = '14.7868' )
      ( unit_code = 'TSP'  unit_text = 'Teaspoon'   category = 'VOLUME' factor_to_base = '4.92892' )
      ( unit_code = 'ML'   unit_text = 'Milliliter' category = 'VOLUME' factor_to_base = '1' )
      ( unit_code = 'L'    unit_text = 'Liter'      category = 'VOLUME' factor_to_base = '1000' )
      ( unit_code = 'G'    unit_text = 'Gram'       category = 'WEIGHT' factor_to_base = '1' )
      ( unit_code = 'KG'   unit_text = 'Kilogram'   category = 'WEIGHT' factor_to_base = '1000' )
      ( unit_code = 'OZ'   unit_text = 'Ounce'      category = 'WEIGHT' factor_to_base = '28.3495' )
      ( unit_code = 'LB'   unit_text = 'Pound'      category = 'WEIGHT' factor_to_base = '453.592' )
    ) ).
    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.
