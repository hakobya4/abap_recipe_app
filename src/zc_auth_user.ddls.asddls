@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for User'
@Metadata.allowExtensions: true
define root view entity ZC_AUTH_USER
  provider contract transactional_query
  as projection on ZI_AUTH_USER
{
  key UserUuid,
      Username,
      CreatedAt,
  _Session : redirected to ZC_AUTH_SESS
}
