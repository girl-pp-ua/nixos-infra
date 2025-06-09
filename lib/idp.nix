{ domain, client_id }:
{
  # kanidm
  oidc_discovery_prefix = "https://${domain}/oauth2/openid/${client_id}";
  oidc_discovery = "https://${domain}/oauth2/openid/${client_id}/.well-known/openid-configuration";
  rfc8144_authorization_server_metadata = "https://${domain}/oauth2/openid/${client_id}/.well-known/oauth-authorization-server";
  user_auth = "https://${domain}/ui/oauth2";
  api_auth = "https://${domain}/oauth2/authorise";
  token_endpoint = "https://${domain}/oauth2/token";
  rfc7662_token_introspection = "https://${domain}/oauth2/token/introspect";
  rfc7662_token_revocation = "https://${domain}/oauth2/token/revoke";
  oidc_issuer_uri = "https://${domain}/oauth2/openid/${client_id}";
  oidc_user_info = "https://${domain}/oauth2/openid/${client_id}/userinfo";
  token_signing_public_key = "https://${domain}/oauth2/openid/${client_id}/public_key.jwk";
}
