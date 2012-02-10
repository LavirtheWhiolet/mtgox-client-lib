require 'requirements'
require 'exchange'
require 'mathn'
require 'socket.io'
require 'utils'
require 'faraday'


class MtGox < Exchange
  
  # TODO: Messages handling should be rewritten in this class.
  # Currently one can not subscribe to Ticker and to send authenticated
  # requests (which imply response) simultaneously.
  
  # Mt. Gox sends money values multiplied by some number. This map maps
  # ISO-4217 currency code to the mutliplier Mt. Gox applies.
  # 
  # Remark: the multipliers should be Integer numbers!
  # 
  CURRENCY_MULTIPLIERS = {
    "BTC" => 1E8.to_i,
    "USD" => 1E5.to_i,
    "JPY" => 1E3.to_i,
  }
  
  # tells MtGox to use or to not use secure protocols (depending
  # on +value+) when connecting to the actual exchange. Unsecure connection
  # is usually faster (especially at establishing stage) but, as the name
  # implies, it is unsecure.
  # 
  # It returns this MtGox.
  # 
  def use_secure_connection(value = true)
    # 
    return if @use_secure_connection == value
    # 
    close()
    @use_secure_connection = value
    #
    return self
  end
  
  def name
    "Mt. Gox"
  end
  
  def ticker
    @ticker or (@ticker = request_ticker())
  end
  
  def next_ticker
    once do
      # Read next message.
      msg = connection.receive()
      # Skip non-ticker messages.
      redo unless msg.is_a?(Socket_IO::JSONMsg) and msg["channel"] == "d5f06780-30a8-4a48-a2f8-7ed181b4a13f" and msg["ticker"]
      # Skip tickers in non-current currency.
      redo if msg["ticker"]["buy"]["currency"] != currency
      #
      new_ticker = parse_ticker(msg["ticker"])
      # 
      redo if new_ticker == @ticker
      #
      return @ticker = new_ticker
    end
  end
  
  def close()
    # Close connection to actual exchange (if needed).
    (@conn.close(); @conn = nil) if @conn
  end
  
  def currency
    "USD"
  end
  
  def item
    "BTC"
  end
  
  def virtual_client(virtual_account_filename)
    VirtualClient.new(virtual_account_filename, self)
  end
  
  def initialize  # :nodoc:
    @ticker = nil
    @use_secure_connection = true
    @conn = nil
  end
  
  private_class_method :new
  
  begin
    @@instance = new
  end
  
  # MtGox instance.
  # 
  # Remark: don't forget to #close() the instance after you have used it!
  # 
  def self.instance; @@instance; end
  
  class VirtualClient < Exchange::VirtualClient
    
    def commission
      "0.6".to_rational / 100
    end
    
  end
  
  private
  
  # Socket_IO connection to actual exchange.
  def connection
    # Establish connection (if not established yet).
    if not @conn then
      # Connect.
      @conn =
        if @use_secure_connection then Socket_IO.open("https://socketio.mtgox.com/socket.io")
        else Socket_IO.open("http://socketio.mtgox.com/socket.io"); end
      # Subscribe to ticker.
      @conn.send Socket_IO::JSONMsg[
        "op" => "mtgox.subscribe",
        "type" => "ticker"
      ]
    end
    #
    return @conn
  end
  
  def parse_value(value_as_json_script)
    s = value_as_json_script
    return s["value_int"].to_i / CURRENCY_MULTIPLIERS[s["currency"]]
  end
  
  def parse_ticker(ticker_as_json_script)
    t = ticker_as_json_script
    return Ticker.new(
      parse_value(t["sell"]),
      parse_value(t["buy"])
    )    
  end
  
  def request_ticker()
    return next_ticker
    # TODO: Send explicit request to the exchange, don't wait until the ticker
    # changes.
# 
# Following code does not work because Mt. Gox sends different tickers
# when using HTTP API and Socket.IO connection.
# 
#    # Try to request the Ticker using HTTP API version 1.
#    begin
#      #
#      conn = Faraday.new(
#        :headers => {
#          :accept => "application/json",
#          :user_agent => "Mt. Gox Client Library",
#        },
#        :ssl => {:verify => @use_secure_connection},
#        :url => "https://mtgox.com"
#      )
#      # Request!
#      resp = conn.get("/api/1/#{item}#{currency}/public/ticker")
#      # Parse response.
#      if resp.status != 200 then raise HTTPAPIRequestFailure; end
#      body = resp.body
#      body = JSON.parse(resp.body)
#      ticker_json = body["return"] or raise %Q{Invalid format of response (may be this implementation is out of date?):\n#{resp.body}}
#      return parse_ticker(ticker_json)
#    # Fall back to next ticker. It's too late to get current one.
#    rescue Errno::ECONNRESET, HTTPAPIRequestFailed
#      return next_ticker
#    end
  end
  
  class HTTPAPIRequestFailed < Exception; end
  
end


__END__

# Here I was learning how to send authenticated commands via MtGox. Socket.IO.

require 'requirements'
require 'socket.io'
require 'json'
require 'openssl'
require 'base64'
require 'mathn'


class String
  
  # is the same as [self].pack(format).
  # 
  # See Array#pack() for details.
  # 
  def pack(format)
    [self].pack(format)
  end
  
end


include Socket_IO_Constants
socket = Socket_IO.open('http://socketio.mtgox.com/socket.io')

api_key = '8789e082-f807-43d7-b196-deaccfab7f6a'.gsub('-', '').pack('H*')
api_secret = Base64.decode64(<<-BASE64)
  0eczAUpxMZuXJkPaCFKvdP9ITAOI91AULndXbaQiTvv909XzwoKRkm2XNVu8nQOGHFg8JO08whY
  3p1dKd518rA==
BASE64

nonce = (Time.now.to_f * 1000000).to_i
req_id = "my_first_request"

call = {
  :id => req_id,
  :call => "private/order/add",
  :params => {
    :type => "ask",
    :amount_int => 1000000,
    :price_int => 590000,
  },
  :nonce => nonce,
  :item => "BTC",
  :currency => "USD"
}

call_str = call.to_json

sign = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA512.new, api_secret, call_str)

call = Base64.encode64(api_key + sign + call_str)

req = {
  :op => "call",
  :id => req_id,
  :context => "mtgox.com",
  :call => call
}

puts "Receiving `Connect' message..."
puts socket.receive
puts "Sending request: #{req.to_json}"
socket.send JSONMsg[req]
puts "Receiving all messages."
loop do
  puts socket.receive
end
