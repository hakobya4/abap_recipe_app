@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Ingredient'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_RCP_INGREDIENT
  as select from zrcp_ingredient
  association        to parent ZI_RCP_RECIPE as _Recipe    on $projection.RecipeUuid = _Recipe.RecipeUuid
  association [0..1] to ZI_RCP_UOM           as _Uom       on $projection.UnitCode = _Uom.UnitCode
  association [0..1] to ZI_RCP_UOM           as _TargetUom on $projection.TargetUnitCode = _TargetUom.UnitCode
{
  key ingredient_uuid    as IngredientUuid,
      recipe_uuid        as RecipeUuid,
      sort_order         as SortOrder,
      ingredient_name    as IngredientName,
      quantity           as Quantity,
      unit_code          as UnitCode,
      density            as Density,
      is_obtained        as IsObtained,
      target_unit_code   as TargetUnitCode,
      scaled_quantity    as ScaledQuantity,
      converted_quantity as ConvertedQuantity,

      _Recipe,
      _Uom,
      _TargetUom
}
