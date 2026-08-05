@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View User Table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_AUTH_USER
  as select from zauth_user
  association [0..*] to ZI_AUTH_SESS as _Session on $projection.UserUuid = _Session.UserUuid
{
  key user_uuid       as UserUuid,
      username        as Username,
      password_hash   as PasswordHash,
      password_salt   as PasswordSalt,
      hash_iterations as HashIterations,

      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,

      _Session
}
