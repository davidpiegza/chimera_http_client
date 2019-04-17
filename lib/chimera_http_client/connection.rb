# The get, post, put, patch and delete methods return either a Response or a Error
# The bang methods get!, post!, put!, patch! and delete! raise a Error in case of failure

module ChimeraHttpClient
  class Connection
    USER_AGENT = "ChimeraHttpClient (by mediafinger)".freeze

    def initialize(base_url:, user_agent: USER_AGENT, timeout: nil, verbose: false)
      fail(ChimeraHttpClient::ParameterMissingError, "base_url expected, but not given") if base_url.nil?
      @base_url = base_url
      @timeout = timeout

      define_bang_methods

      Typhoeus::Config.user_agent = user_agent
      Typhoeus::Config.verbose = verbose
      Typhoeus::Config.memoize = false
      # Typhoeus::Config.cache
    end

    def request
      @request ||= Request.new
    end

    def get(endpoint, options = {})
      headers = extract_headers(options, default_headers)

      request.run(url: url(endpoint), method: :get, options: augmented_options(options), headers: headers)
    end

    def post(endpoint, options = {})
      run_with_body(:post, endpoint, options)
    end

    def put(endpoint, options = {})
      run_with_body(:put, endpoint, options)
    end

    def patch(endpoint, options = {})
      run_with_body(:patch, endpoint, options)
    end

    def delete(endpoint, options = {})
      run_with_body(:delete, endpoint, options.merge(body_optional: true))
    end

    private

    # Add default values to call options
    def augmented_options(options)
      options[:timeout] ||= @timeout

      options
    end

    def run_with_body(method, endpoint, options = {})
      body = extract_body(options)
      headers = extract_headers(options, default_headers)

      request.run(url: url(endpoint), method: method, body: body, options: augmented_options(options), headers: headers)
    end

    # Build URL out of @base_url and endpoint given as String or Array, while trimming redundant "/"
    def url(endpoint)
      trimmed_endpoint = Array(endpoint).map { |e| trim(e) }
      [@base_url.chomp("/"), trimmed_endpoint].flatten.reject(&:empty?).join("/")
    end

    # Remove leading and trailing "/" from a give part of a String (usually URL or endpoint)
    def trim(element)
      element.to_s.sub(%r{^\/}, "").chomp("/")
    end

    def extract_body(options)
      body = options.delete(:body)
      body_optional = options.delete(:body_optional)
      fail(ChimeraHttpClient::ParameterMissingError, "body expected, but not given") if body.nil? && !body_optional
      body
    end

    def extract_headers(options, headers)
      given_headers = options.delete(:headers) || {}
      headers.merge(given_headers)
    end

    def default_headers
      { "Content-Type" => "application/json" }
    end

    # get! post! put! patch! delete! return an Response when successful, but raise an Error otherwise
    def define_bang_methods
      {
        get!:    :get,
        post!:   :post,
        put!:    :put,
        patch!:  :patch,
        delete!: :delete,
      }.each do |method_name, implemented_method|
        self.class.send(:define_method, method_name) do |endpoint, options = {}|
          result = public_send(implemented_method, endpoint, options)

          fail result if result.error?

          result
        end
      end
    end
  end
end
