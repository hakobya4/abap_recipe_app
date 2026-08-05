CLASS lhc_User DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR User RESULT result.

    METHODS register FOR MODIFY
      IMPORTING keys FOR ACTION User~register RESULT result.

    METHODS login FOR MODIFY
      IMPORTING keys FOR ACTION User~login RESULT result.

ENDCLASS.

CLASS lhc_User IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD register.

    DATA lt_create TYPE TABLE FOR CREATE zi_auth_user\\User.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      DATA(lv_username) = <key>-%param-Username.
      DATA(lv_password) = <key>-%param-Password.

      IF lv_username IS INITIAL OR lv_password IS INITIAL.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-User.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Username and password are both required.' )
        ) TO reported-User.
        CONTINUE.
      ENDIF.

      SELECT SINGLE user_uuid FROM zauth_user
        WHERE username = @lv_username
        INTO @DATA(lv_existing_uuid).

      IF sy-subrc = 0.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-User.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'That username is already taken.' )
        ) TO reported-User.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lv_salt) = zcl_auth_password_hash=>generate_salt( ).
          DATA(lv_hash) = zcl_auth_password_hash=>hash(
                            iv_password   = lv_password
                            iv_salt       = lv_salt
                            iv_iterations = zcl_auth_password_hash=>c_default_iterations ).
        CATCH cx_uuid_error cx_abap_message_digest INTO DATA(lx_hash_error).
          APPEND VALUE #( %cid = <key>-%cid ) TO failed-User.
          APPEND VALUE #(
            %cid = <key>-%cid
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = |Could not process password: { lx_hash_error->get_text( ) }| )
          ) TO reported-User.
          CONTINUE.
      ENDTRY.

      APPEND VALUE #(
        %cid           = <key>-%cid
        Username       = lv_username
        PasswordHash   = lv_hash
        PasswordSalt   = lv_salt
        HashIterations = zcl_auth_password_hash=>c_default_iterations
      ) TO lt_create.

    ENDLOOP.

    CHECK lt_create IS NOT INITIAL.

    MODIFY ENTITIES OF zi_auth_user IN LOCAL MODE
      ENTITY User
        CREATE FIELDS ( Username PasswordHash PasswordSalt HashIterations )
        WITH lt_create
      MAPPED   DATA(ls_create_mapped)
      FAILED   DATA(failed_create)
      REPORTED DATA(reported_create).

    failed-User   = CORRESPONDING #( BASE ( failed-User ) failed_create-User ).
    reported-User = CORRESPONDING #( BASE ( reported-User ) reported_create-User ).

    READ ENTITIES OF zi_auth_user IN LOCAL MODE
      ENTITY User ALL FIELDS
        WITH VALUE #( FOR ls_m IN ls_create_mapped-user ( %tky = CORRESPONDING #( ls_m-%pky ) ) )
      RESULT DATA(created_users).

    LOOP AT ls_create_mapped-user INTO DATA(ls_mapped).
      READ TABLE created_users WITH KEY UserUuid = ls_mapped-%pky-UserUuid INTO DATA(ls_created_user).
      APPEND VALUE #(
        %cid   = ls_mapped-%cid
        %param = COND #( WHEN sy-subrc = 0
                          THEN CORRESPONDING #( ls_created_user )
                          ELSE VALUE #( UserUuid = ls_mapped-%pky-UserUuid ) )
      ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD login.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      DATA(lv_username) = <key>-%param-Username.
      DATA(lv_password) = <key>-%param-Password.

      SELECT SINGLE user_uuid, username, password_hash, password_salt, hash_iterations, created_at
        FROM zauth_user
        WHERE username = @lv_username
        INTO @DATA(ls_user).

      DATA(lv_valid) = abap_false.

      IF sy-subrc = 0.
        TRY.
            DATA(lv_recomputed) = zcl_auth_password_hash=>hash(
                                     iv_password   = lv_password
                                     iv_salt       = CONV #( ls_user-password_salt )
                                     iv_iterations = CONV #( ls_user-hash_iterations ) ).

            IF lv_recomputed = ls_user-password_hash.
              lv_valid = abap_true.
            ENDIF.
          CATCH cx_abap_message_digest.
            lv_valid = abap_false.
        ENDTRY.
      ENDIF.

      IF lv_valid = abap_false.
        APPEND VALUE #( %cid = <key>-%cid ) TO failed-User.
        APPEND VALUE #(
          %cid = <key>-%cid
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Invalid username or password.' )
        ) TO reported-User.
        CONTINUE.
      ENDIF.

      " Enforce one active session per user - remove any existing
      " session(s) for this user before creating the new one.
      SELECT session_uuid FROM zauth_sess
        WHERE user_uuid = @ls_user-user_uuid
        INTO TABLE @DATA(lt_existing_sessions).

      IF lt_existing_sessions IS NOT INITIAL.
        MODIFY ENTITIES OF zi_auth_sess
          ENTITY Session
            DELETE FROM VALUE #( FOR ls_sess IN lt_existing_sessions
                                  ( %tky = VALUE #( SessionUuid = ls_sess-session_uuid ) ) )
          FAILED   DATA(failed_old_sess)
          REPORTED DATA(reported_old_sess).
      ENDIF.

      DATA(lv_now) = utclong_current( ).

      MODIFY ENTITIES OF zi_auth_sess
        ENTITY Session
          CREATE FIELDS ( UserUuid CreatedAt ExpiresAt )
          WITH VALUE #( (
            %cid      = |{ <key>-%cid }_session|
            UserUuid  = ls_user-user_uuid
            CreatedAt = lv_now
            ExpiresAt = utclong_add( val = lv_now minutes = 30 )
          ) )
        REPORTED DATA(reported_sess)
        FAILED   DATA(failed_sess).

      APPEND VALUE #(
        %cid   = <key>-%cid
        %param = VALUE #(
                   UserUuid  = ls_user-user_uuid
                   Username  = ls_user-username
                   CreatedAt = ls_user-created_at
                 )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
