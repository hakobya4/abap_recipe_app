@EndUserText.label: 'Abstract Entity for Recipe Import'

define abstract entity ZI_RCP_IMPORT_P
{
  Url         : abap.string( 0 );
  JsonLd      : abap.string( 0 );
  SessionUuid : sysuuid_x16;
  
}
