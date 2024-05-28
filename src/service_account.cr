require "./resource"

module Google
  struct ServiceAccount
    struct Key
      include Resource

      getter type : String
      getter project_id : String
      getter private_key_id : String
      getter private_key : String
      getter client_email : String
      getter client_id : String
      getter auth_uri : URI
      getter token_uri : URI
      getter auth_provider_x509_cert_url : URI
      getter universe_domain : String
    end
  end
end
