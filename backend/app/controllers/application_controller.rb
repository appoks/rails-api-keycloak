class ApplicationController < ActionController::API
    before_action :require_jwt
  
    def require_jwt
      token = request.headers["HTTP_AUTHORIZATION"]
      if !token
        head :forbidden
      end
      if !valid_token(token)
        head :forbidden
      end
    end

    def is_papa
      token = request.headers["HTTP_AUTHORIZATION"]

      begin
        rsa_key = create_cert
        decoded_token = JWT.decode(token, rsa_key.public_key, true, { algorithm: "RS256" })
        p decoded_token

        groups = decoded_token[0]["groups"]
        p groups

        p groups.include? "/papas"
        return groups.include? "/papas"
        
        
      rescue JWT::DecodeError
        Rails.logger.warn "Error decoding the JWT"
      end
    end
  
    private

    def create_cert
    public_key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqciCym8vkFScUVZoQ/CG4bE7CUZ6KdADCJO3qj6sJkFi+Dlu37dPx3/Q2l90n+dYsFHu/XAW07PcBVUuFjlt8KMbJCfekbcaKk+SsGoVE5H0ZJSb41pPqDHh2oV+ucjdZ+Ce9BY2IzlcbUAgX7go6p3X6XuEUGkQuU83aTGf2z0Msit3rGf3gz3QVcKKBFL2Lj8ZE3U/e/o9AgtejHWxnQotWTn7fa98bIk0YFGD+Uip1N0cmFfXIGnA+5xcwTgljp9XZYtE26RVEer0KCpK7gVRSIAshhAtqIH8I10buxnOqTNui1a1G7Aj3t0TdQDAt/8qnaTqDLtNjBIdlZSG3wIDAQAB"
    rsa_pub_key = "-----BEGIN PUBLIC KEY-----\n" + public_key + "\n-----END PUBLIC KEY-----"
    rsa_key = OpenSSL::PKey::RSA.new rsa_pub_key
    end

    def valid_token(token)
      unless token
        return false
      end

      token.gsub!('Bearer ','')

      begin
        rsa_key = create_cert
        decoded_token = JWT.decode(token, rsa_key.public_key, true, { algorithm: "RS256" })
        return true
      rescue JWT::DecodeError
        Rails.logger.warn "Error decoding the JWT"
      end
      false
    end
  end