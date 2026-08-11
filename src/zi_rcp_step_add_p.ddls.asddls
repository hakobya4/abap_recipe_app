@EndUserText.label: 'Abstract Entity for Step Add'

define abstract entity ZI_RCP_STEP_ADD_P
{
  RecipeUuid  : sysuuid_x16;
  Instruction : abap.string( 0 );
}
