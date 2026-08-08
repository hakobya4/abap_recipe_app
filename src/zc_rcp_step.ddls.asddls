@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Instruction'
@Metadata.allowExtensions: true
define view entity ZC_RCP_STEP
  as projection on ZI_RCP_STEP
{
  key StepUuid,
      RecipeUuid,
      StepNumber,
      Instruction,
      _Recipe : redirected to parent ZC_RCP_RECIPE
}
