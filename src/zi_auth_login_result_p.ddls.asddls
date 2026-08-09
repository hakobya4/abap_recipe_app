@EndUserText.label: 'Abstract Entity for Login Result'
define abstract entity ZI_AUTH_LOGIN_RESULT_P
{
  UserUuid    : sysuuid_x16;
  Username    : abap.char( 40 );
  CreatedAt   : abap.utclong;
  SessionUuid : sysuuid_x16;
}
