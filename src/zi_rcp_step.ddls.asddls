@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Insturction Table'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_RCP_STEP
  as select from zrcp_step
  association to parent ZI_RCP_RECIPE as _Recipe on $projection.RecipeUuid = _Recipe.RecipeUuid
{
  key step_uuid    as StepUuid,
      recipe_uuid  as RecipeUuid,
      step_number  as StepNumber,
      instruction  as Instruction,
      _Recipe
}
