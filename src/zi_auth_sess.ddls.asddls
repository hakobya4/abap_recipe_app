@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Session Table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_SESS
  as select from zauth_sess
{
  key session_uuid as SessionUuid,
      user_uuid     as UserUuid,

      @Semantics.systemDateTime.createdAt: true
      created_at    as CreatedAt,
      expires_at    as ExpiresAt
}
