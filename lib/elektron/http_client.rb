require 'uri'
require 'json'
require 'net/http'
require_relative './utils/uri_helper'
require_relative './errors/api_response'

module Elektron
  # http client
  class HttpClient
    include UriHelper

    # Content-types
    CONTENT_TYPE_JSON = 'application/json'.freeze
    CONTENT_TYPE_FORM = 'application/x-www-form-urlencoded'.freeze

    DEFAULT_OPTIONS = {
      open_timeout: 10,
      read_timeout: 60,
      keep_alive_timeout: 60
    }.freeze

    def initialize(url, options = {})
      uri = URI.parse(url)
      options = options.clone
      @headers = options.delete(:headers) || {}
      @connection = Net::HTTP.new(uri.host, uri.port, :ENV)

      http_options = {}.merge(DEFAULT_OPTIONS)

      if uri.scheme == 'https'
        http_options[:use_ssl] = true
        if options.fetch(:verify_ssl, true) == false
          http_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
        end
      end

      http_options.merge!(options[:client]) if options[:client]
      # set attributes
      http_options.each { |key, value| @connection.send("#{key}=", value) }

      return unless options[:debug]
      @connection.set_debug_output($stdout)
    end

    # Open a connection for multiple calls.
    # - Accepts a block, otherwise just opens the connection.
    # - You'll need to close the connection if you just open it.
    def start
      if block_given?
        # Open the connection.
        @connection.start unless @connection.started?

        # Yield to the calling block.
        yield(self)

        # Clean up the connection.
        @connection.finish if @connection.started?
      else
        # Open the connection.
        @connection.start unless @connection.started?
      end
    end

    # Clean up the connection if needed.
    def finish
      @connection.finish if @connection.started?
    end

    ############ REQUESTS ############
    # DELETE
    def delete(path, headers = {})
      headers = {}.merge(@headers).merge(headers)
      request = Net::HTTP::Delete.new(path, headers)
      perform(request)
    end

    # GET
    def get(path, *args)
      params = args.length > 0 ? args[0] : {}
      headers = args.length > 1 ? args[1] : {}
      headers = {}.merge(@headers).merge(headers)
      perform(Net::HTTP::Get.new(to_url(path, params), headers))
    end

    # HEAD
    def head(path, headers = {})
      headers = {}.merge(@headers).merge(headers)
      perform(Net::HTTP::Head.new(path, headers))
    end

    # OPTIONS
    def options(path, headers = {})
      headers = {}.merge(@headers).merge(headers)
      perform(Net::HTTP::Options.new(path, headers))
    end

    # PATCH
    def patch(path, *args)
      data = args.length > 0 ? args[0] : {}
      headers = args.length > 1 ? args[1] : {}
      headers = {}.merge(@headers).merge(headers)
      request = Net::HTTP::Patch.new(path, headers)
      request.content_type = CONTENT_TYPE_JSON
      if data && !data.empty?
        request.body = json?(data) ? data : JSON.generate(data)
      end
      perform(request)
    end

    # POST
    def post(path, *args)
      data = args.length > 0 ? args[0] : {}
      headers = args.length > 1 ? args[1] : {}
      headers = {}.merge(@headers).merge(headers)

      request = Net::HTTP::Post.new(path, headers)
      request.content_type = CONTENT_TYPE_JSON
      if data && !data.empty?
        request.body = json?(data) ? data : JSON.generate(data)
      end
      perform(request)
    end

    # PUT
    def put(path, *args)
      data = args.length > 0 ? args[0] : {}
      headers = args.length > 1 ? args[1] : {}
      headers = {}.merge(@headers).merge(headers)

      request = Net::HTTP::Put.new(path, headers)
      request.content_type = CONTENT_TYPE_JSON
      if data && !data.empty?
        request.body = json?(data) ? data : JSON.generate(data)
      end
      perform(request)
    end

    protected

    # Perform the request.
    def perform(request)
      # Shore up default headers for the request.
      request['Accept'] = CONTENT_TYPE_JSON
      request['Connection'] = 'keep-alive'
      request['User-Agent'] = "Elektron #{Elektron::VERSION}"

      # Actually make the request.
      # start http session
      #start
      response = @connection.request(request)
      # close http session
      #finish

      # Net::HTTPResponse.value will raise an error for non-200 responses.
      #   Simpler than trying to detect every possible exception.
      parse(response.value || response)
    rescue Net::ProtoServerError => e
      raise ::Elektron::Errors::ApiResponse, e.response
    end

    def parse(response)
      # Parse the response as JSON if possible.
      if response.body && response.content_type == CONTENT_TYPE_JSON
        response.body = begin
                          JSON.parse(response.body)
                        rescue JSON::ParserError => _e
                          # do nothing
                          response.body
                        end
      end
      response
    end

    def json?(string)
      return false unless string.is_a?(String)
      JSON.parse(string) && true
    rescue JSON::ParserError => _e
      false
    end
  end
end