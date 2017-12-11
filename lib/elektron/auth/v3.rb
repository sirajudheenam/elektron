require_relative '../http_client'

module Elektron
  module Auth
    class V3
      attr_reader :context, :token_value

      def initialize(auth_conf, options = {})
        @auth_conf = auth_conf
        @options = options
        @client = Elektron::HttpClient.new(auth_conf[:url], @options)
        response = @client.post('/v3/auth/tokens', credentials.to_json)
        @context = response.body
        @token_value = response['x-subject-token']
      end

      def user
        user = {
          'domain' => {},
          'password' => @auth_conf[:password]
        }

        if @auth_conf[:user_name]
          user['name'] = @auth_conf[:user_name]
        else
          user['id'] = @auth_conf[:user_id]
        end

        if @auth_conf[:user_domain_name]
          user['domain']['name'] = @auth_conf[:user_domain_name]
        else
          user['domain']['id'] = @auth_conf[:user_domain_id]
        end
        user
      end

      def scope
        scope = {}
        if @auth_conf[:scope_project_id]
          scope['project'] = { 'id' => @auth_conf[:scope_project_id] }
        elsif @auth_conf[:scope_project_name]
          scope['project'] = { 'name' => @auth_conf[:scope_project_name] }
          if @auth_conf[:scope_project_domain_name]
            scope['project']['domain'] = {
              'name' => @auth_conf[:scope_project_domain_name]
            }
          elsif @auth_conf[:scope_project_domain_id]
            scope['project']['domain'] = {
              'id' => @auth_conf[:scope_project_domain_id]
            }
          end
        elsif @auth_conf[:scope_domain_name]
          scope['domain'] = { 'name' => @auth_conf[:scope_domain_name] }
        elsif @auth_conf[:scope_domain_id]
          scope['domain'] = { 'id' => @auth_conf[:scope_domain_id] }
        elsif @auth_conf[:unscoped]
          scope = 'unscoped'
        end
        scope
      end

      def credentials
        identity = if @auth_conf[:token]
                     {
                       'methods' => ['token'],
                       'token' => { 'id' => @auth_conf[:token] }
                     }
                   else
                     {
                       'methods' => ['password'],
                       'password' => {
                         'user' => user
                       }
                     }
                   end

        auth = {
          'identity' => identity
        }
        s = scope
        s.length.positive? && auth['scope'] = scope
        { 'auth' => auth }
      end
    end
  end
end