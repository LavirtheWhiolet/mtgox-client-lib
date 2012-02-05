require 'requirements'
require 'mathn'
require 'socket.io'
require 'utils'


# Model of the Mt. Gox exchange.
# 
# Remark: don't forget to #close() the MtGox instance after you have used it!
# 
# TODO: This class needs more functionality.
# 
class MtGox
  
  # TODO: Messages handling should be rewritten in this class.
  # Currently one can not subscribe to Ticker and to send authenticated
  # requests (which imply response) simultaneously.
  
  # Mt. Gox sends money values multiplied by some number. This map
  # maps ISO-4217 currency code to the mutliplier Mt. Gox applies.
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
  # returns MtGox.
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
  
  # Current Ticker.
  def ticker
    @ticker or next_ticker
  end
  
  # Ticker next after current (yes, this method waits for the Ticker change).
  def next_ticker
    once do
      # Read next message.
      msg = connection.receive()
      # Skip non-ticker messages.
      redo unless msg.is_a?(Socket_IO::JSONMsg) and msg["channel"] == "d5f06780-30a8-4a48-a2f8-7ed181b4a13f" and msg["ticker"]
      # Skip tickers in non-current currency.
      redo if msg["ticker"]["buy"]["currency"] != currency
      #
      new_ticker = Ticker.new(
        parse(msg["ticker"]["sell"]),
        parse(msg["ticker"]["buy"])
      )
      # 
      redo if new_ticker == @ticker
      #
      return @ticker = new_ticker
    end
  end
  
  # 
  # frees all system resources grabbed by MtGox, i. e. closes
  # all connections, frees all mutexes etc. The instance remains usable
  # but further operations require extra time to grab the freed resources again.
  # 
  def close()
    # Close connection to actual exchange (if needed).
    (@conn.close(); @conn = nil) if @conn
  end
  
  # ISO-4217 code of the currency you are currently working with.
  def currency
    "USD"
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
  
  class Ticker
    
    def initialize(sell, buy)
      @sell, @buy = sell, buy
    end
    
    # Sell price, MtGox#currency per bitcoin.
    attr_reader :sell
    
    alias sell_price sell
    
    # Buy price, MtGox#currency per bitcoin.
    attr_reader :buy
    
    alias buy_price buy
    
    def to_s
      "Sell: #{sell.to_f} Buy: #{buy.to_f}"
    end
    
    def == other
      self.class == other.class &&
      self.sell == other.sell &&
      self.buy == other.buy
    end
    
    alias eql? ===
    
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
  
  def parse(value_as_json_script)
    s = value_as_json_script
    return s["value_int"].to_i / CURRENCY_MULTIPLIERS[s["currency"]]
  end
  
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
