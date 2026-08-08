@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Unit of Measurement'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RCP_UOM
  as select from zrcp_uom
{
  key unit_code      as UnitCode,
      unit_text      as UnitText,
      category       as Category,
      factor_to_base as FactorToBase
}
