@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for UOM'
define root view entity ZC_RCP_UOM
  provider contract transactional_query
  as projection on ZI_RCP_UOM
{
  key UnitCode,
      UnitText,
      Category,
      FactorToBase
}
