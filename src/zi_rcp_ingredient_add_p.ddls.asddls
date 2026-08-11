@EndUserText.label: 'Abstract Entity for Ingredient Add'
define abstract entity ZI_RCP_INGREDIENT_ADD_P
{
  RecipeUuid     : sysuuid_x16;
  IngredientName : abap.char( 80 );
  Quantity       : abap.dec( 9, 3 );
  UnitCode       : abap.char( 10 );
  Density        : abap.dec( 7, 4 );
  TargetUnitCode : abap.char( 10 );
}
