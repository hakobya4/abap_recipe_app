@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Recipe'
@Metadata.allowExtensions: true
define root view entity ZC_RCP_RECIPE
  provider contract transactional_query
  as projection on ZI_RCP_RECIPE
{
  key RecipeUuid,
      UserUuid,
      Title,
      Description,
      Servings,
      ServingsMultiplier,
      PrepMinutes,
      CookMinutes,
      CreatedAt,
      LastChangedAt,
      
      _Ingredient : redirected to composition child ZC_RCP_INGREDIENT,
      _Step       : redirected to composition child ZC_RCP_STEP
}
