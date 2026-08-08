@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Ingredient'
@Metadata.allowExtensions: true
define view entity ZC_RCP_INGREDIENT
  as projection on ZI_RCP_INGREDIENT
{
  key IngredientUuid,
      RecipeUuid,
      SortOrder,
      IngredientName,
      Quantity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_RCP_UOM', element: 'UnitCode' } }]
      UnitCode,
      Density,
      IsObtained,
      ScaledQuantity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_RCP_UOM', element: 'UnitCode' } }]
      TargetUnitCode,
      ConvertedQuantity,
      _Recipe    : redirected to parent ZC_RCP_RECIPE,
      _Uom       : redirected to ZC_RCP_UOM,
      _TargetUom : redirected to ZC_RCP_UOM
}
