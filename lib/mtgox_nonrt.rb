require 'mtgox'


# Non-realtime version of MtGox.
class MtGoxNonRT < MtGox
  
  def name
    "Mt. Gox (non-realtime)"
  end
  
  def ticker
    @ticker or (@ticker = request_ticker())
  end
  
  def next_ticker
    once do
      sleep 10  # Mt. Gox does not allow too frequent polling.
      old_ticker = @ticker
      @ticker = request_ticker()
      redo if @ticker == old_ticker
    end
    #
    return @ticker
  end
  
  def close()
    # Do nothing.
  end
  
  private_class_method :new
  
  begin
    @@instance = new
  end
  
  # MtGoxNonRT instance.
  # 
  # Remark: don't forget to #close() the instance after you have used it!
  #
  def self.instance; @@instance; end
  
  private
  
  def request_ticker()
    begin
      # Connect!
      conn = Faraday.new(
        :headers => {
          :accept => "application/json",
          :user_agent => "Mt. Gox Client Library",
        },
        :ssl => {:verify => use_secure_connection?},
        :url => "https://mtgox.com"
      )
      # Request!
      resp = conn.get("/api/1/#{item}#{currency}/public/ticker")
      # Parse response.
      if resp.status != 200 then raise HTTPAPIRequestFailure; end
      body = resp.body
      body = JSON.parse(resp.body)
      ticker_json = body["return"] or raise %Q{Invalid format of response (may be this implementation is out of date?):\n#{resp.body}}
      return parse_ticker(ticker_json)
    # Sometimes Mt. Gox fails to respond to the request. Retry if that's the
    # case.
    rescue Errno::ECONNRESET, HTTPAPIRequestFailed
      sleep 1
      retry
    end
  end
  
  class HTTPAPIRequestFailed < Exception; end
  
end

