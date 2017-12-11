# forezen_string_literal: true
require_relative './auth/v2'
require_relative './auth/v3'
require_relative './auth/token_context'
require_relative './errors/unknown_identity_version'
require_relative './errors/token_expired'

module Elektron
  # Abstract class
  class AuthSession
    include Elektron::TokenContext

    VERSIONS = %w[V2 V3].freeze

    def self.version(auth_conf, options)
      if options[:version] && VERSIONS.include?(options[:version].to_s.upcase)
        return options[:version].to_s.upcase
      end

      return 'V2' if auth_conf[:tenant_id] || auth_conf[:tenant_name]
      'V3'
    end

    def initialize(auth_conf, options = {})
      @auth_conf = auth_conf
      @options = options
      if @auth_conf[:token_context] && @auth_conf[:token]
        current_context(@auth_conf[:token_context])
        @token = @auth_conf[:token]
      else
        version = self.class.version(auth_conf, options)
        raise Elektron::Errors::UnknownIdentityVersion unless version
        @auth_class ||= Object.const_get("Elektron::Auth::#{version}")
        authenticate
      end
    end

    def token
      enforce_valid_token
      @token
    end

    # def catalog
    #   enforce_valid_token
    #   super
    # end

    protected

    def enforce_valid_token
      if expired?
        # reauthenticate
        unless authenticate
          raise Elektron::Errors::TokenExpired, 'token has been expired'
        end
      end
    end

    def authenticate
      return false unless @auth_class
      auth = @auth_class.new(@auth_conf, @options)
      current_context(auth.context)
      @token = auth.token_value
    end
  end
end