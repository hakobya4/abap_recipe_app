@EndUserText.label: 'Abstract Entity for Ingredient Update'
define abstract entity ZI_RCP_INGREDIENT_UPDATE_P
{
  IngredientName : abap.char( 80 );
  Quantity       : abap.dec( 9, 3 );
  UnitCode       : abap.char( 10 );
  Density        : abap.dec( 7, 4 );
  TargetUnitCode : abap.char( 10 );
}
