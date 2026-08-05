@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Session'
@Metadata.allowExtensions: true
define root view entity ZC_AUTH_SESS
  provider contract transactional_query
  as projection on ZI_AUTH_SESS
{
  key SessionUuid,
      UserUuid,
      CreatedAt,
      ExpiresAt
}
