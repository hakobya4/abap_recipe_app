@EndUserText.label: 'Abstract Entity for Recipe Create'
define abstract entity ZI_RCP_RECIPE_CREATE_P
{
  Title       : abap.string( 0 );
  Description : abap.string( 0 );
  Servings    : abap.int4;
  PrepMinutes : abap.int4;
  CookMinutes : abap.int4;
}
