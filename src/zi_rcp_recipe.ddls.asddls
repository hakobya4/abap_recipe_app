@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Recipe Table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RCP_RECIPE
  as select from zrcp_recipe
  composition [0..*] of ZI_RCP_INGREDIENT as _Ingredient
  composition [0..*] of ZI_RCP_STEP       as _Step
{
  key recipe_uuid          as RecipeUuid,
      user_uuid             as UserUuid,
      title                 as Title,
      description           as Description,
      servings              as Servings,
      servings_multiplier   as ServingsMultiplier,
      prep_minutes          as PrepMinutes,
      cook_minutes          as CookMinutes,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      _Ingredient,
      _Step
}
