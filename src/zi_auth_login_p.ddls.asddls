@EndUserText.label: 'Abstract Entity for Login'

define abstract entity ZI_AUTH_LOGIN_P
{
  Username      : abap.char( 40 );
  @EndUserText.label: 'Password'
  @UI.masked: true
  Password : abap.string( 0 );
}
