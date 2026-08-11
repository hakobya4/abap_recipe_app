@EndUserText.label: 'Abstract Entity for Recipe Update'

define abstract entity ZI_RCP_RECIPE_UPDATE_P
{
  Title              : abap.char( 100 );
  Description        : abap.string( 0 );
  Servings           : abap.int4;
  ServingsMultiplier : abap.dec( 5, 2 );
  PrepMinutes        : abap.int4;
  CookMinutes        : abap.int4;
}
