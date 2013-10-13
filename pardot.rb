#  == Used for interfacing the Pardot API
#
#  http://developer.pardot.com/kb/api-version-3/intro-and-table-of-contents
#

require 'net/http'
require 'uri'
require 'xmlsimple'

class Pardot

  # setup base credentials
  BASE_URL      = 'https://pi.pardot.com/api'
  USER_KEY      = 'YOUR_PROD_USER_KEY'
  API_KEY       = 'YOUR_PROD_API_KEY'
  CAMPAIGN_ID   = 'YOUR_CAMPAIGN_ID' # TODO - make this a passable arguement/param
  USER_EMAIL    = 'YOUR_EMAIL'
  USER_PASS     = 'YOUR_PASS'

  #
  #  Pardot resources
  #
  def get_api_key
    respond_with_hash post("#{BASE_URL}/login/version/3?email=#{USER_EMAIL}&password=#{USER_PASS}&user_key=#{USER_KEY}", :body => '')
  end

  def create_prospect(prospect, api_key)
    respond_with_raw post("#{BASE_URL}/prospect/version/3/do/create/email/#{CGI::escape(prospect.email)}?company=#{CGI::escape(prospect.business_name)}&api_key=#{api_key}&user_key=#{USER_KEY}&campaign_id=#{CAMPAIGN_ID}&phone=#{CGI::escape(prospect.phone)}&zip=#{CGI::escape(prospect.zip)}&address_one=#{CGI::escape(prospect.address)}", :body => 'hello')
    return false
  end
  
  def update_prospect(prospect, api_key)
    respond_with_raw post("#{BASE_URL}/prospect/version/3/do/update/email/#{CGI::escape(prospect.email)}?company=#{CGI::escape(prospect.business_name)}&api_key=#{api_key}&user_key=#{USER_KEY}&campaign_id=#{CAMPAIGN_ID}&phone=#{CGI::escape(prospect.phone)}&zip=#{CGI::escape(prospect.zip)}&address_one=#{CGI::escape(prospect.address)}", :body => 'hello')
    return false
  end

  # returns 1 or 0 depending if the prospect exists or not
  def check_prospect(prospect, api_key)
    res = respond_with_raw get("#{BASE_URL}/prospect/version/3/do/read/email/#{CGI::escape(prospect.email)}?api_key=#{api_key}&user_key=#{USER_KEY}")
    xml = Nokogiri::XML(res)
    ret = xml.at_xpath('.//err').nil? ? 1 : 0
    return ret
  end

  #
  # REST handlers
  #

  def get(url, options = {})
    execute(url, options)
  end

  def put(url, options = {})
    options = {:method => :put}.merge(options)
    execute(url, options)
  end

  def post(url, options = {})
    options = {:method => :post}.merge(options)
    execute(url, options)
  end

  def delete(url, options = {})
    options = {:method => :delete}.merge(options)
    execute(url, options)
  end

  protected

  def respond_with_hash(response)
    XmlSimple.xml_in(response.body, { 'ForceArray' => false, 'SuppressEmpty' => true })
  end

  def respond_with_raw(response)
    response.body
  end


  def to_uri(url)
    begin
      if !url.kind_of?(URI)
        url = URI.parse(url)
      end
    rescue
      raise URI::InvalidURIError, "Invalid url '#{url}'"
    end

    if (url.class != URI::HTTP && url.class != URI::HTTPS)
      raise URI::InvalidURIError, "Invalid url '#{url}'"
    end

    url
  end

  def execute(url, options = {})
    options = {
      :parameters     => {:api_key => API_KEY},
      :debug          => true,
      :http_timeout   => 60,
      :headers        => {},
      :redirect_count => 0,
      :max_redirects  => 10,
      :content_type   => options[:content_type].blank? ? "text/xml" : options[:content_type]
    }.merge(options)

    url = to_uri(url)
    http = Net::HTTP.new(url.host, url.port)

    if url.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    http.open_timeout = http.read_timeout = options[:http_timeout]

    http.set_debug_output $stderr if options[:debug]

    request = case options[:method]
      when :post
        request = Net::HTTP::Post.new(url.request_uri)
      when :put
        request = Net::HTTP::Put.new(url.request_uri)
      when :delete
        request = Net::HTTP::Delete.new(url.request_uri)
      else
        Net::HTTP::Get.new(url.request_uri)
    end
    request.body = options[:body]
    request

    request.content_type = options[:content_type] if options[:content_type]

    options[:headers].each { |key, value| request[key] = value }
    response = http.request(request)

    if response.kind_of?(Net::HTTPRedirection)      
      options[:redirect_count] += 1

      if options[:redirect_count] > options[:max_redirects]
        raise "Too many redirects (#{options[:redirect_count]}): #{url}" 
      end

      redirect_url = redirect_url(response)

      if redirect_url.start_with?('/')
        url = to_uri("#{url.scheme}://#{url.host}#{redirect_url}")
      end

      response = execute(url, options)
    end

    #response.to_yaml
    response
  end

  # From http://railstips.org/blog/archives/2009/03/04/following-redirects-with-nethttp/
  def redirect_url(response)
    if response['location'].nil?
      response.body.match(/<a href=\"([^>]+)\">/i)[1]
    else
      response['location']
    end
  end

end
