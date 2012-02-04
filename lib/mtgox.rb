require 'requirements'
require 'mathn'
require 'socket.io'
require 'utils'


# Model of the Mt. Gox exchange.
# 
# To start using Mt. Gox you should open it. See #open().
# 
# Don't forget to #close() Mt. Gox after you have used it!
# 
# TODO: This class is not ready yet.
# 
class MtGox
  
  # Mt. Gox sends money values multiplied by some number. This map
  # maps ISO-4217 currency code to the mutliplier Mt. Gox applies.
  CURRENCY_MULTIPLIERS = {
    "BTC" => 1E8.to_i,
    "USD" => 1E5.to_i,
    "JPY" => 1E3.to_i,
  }
  
  private_class_method :new
  
  # opens Mt. Gox and returns MtGox instance. If block is given then it is
  # passed with the MtGox instance, and the result of the block is returned.
  # 
  def self.open(use_secure_connection = true, &block)
    #
    result = new(use_secure_connection)
    #
    if block then begin return block[result]; ensure result.close(); end
    else return result; end
  end
  
  def initialize(use_secure_connection)  # :nodoc:
    #
    @conn =
      if use_secure_connection then Socket_IO.open("https://socketio.mtgox.com/socket.io")
      else Socket_IO.open("http://socketio.mtgox.com/socket.io"); end
    #
    @ticker = nil
    # Subscribe to ticker.
    @conn.send Socket_IO::JSONMsg[
      "op" => "mtgox.subscribe",
      "type" => "ticker"
    ]
  end
  
  # Current Ticker.
  def ticker
    @ticker or next_ticker
  end
  
  # Ticker next after current (yes, this method waits for Ticker change).
  def next_ticker
    once do
      # Read next message.
      msg = @conn.receive()
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
  
  def close()
    @conn.close()
    @conn = nil
  end
  
  # ISO-4217 code of the currency you are currently working with.
  def currency
    "USD"
  end
  
  class Ticker
    
    def initialize(sell, buy)
      @sell, @buy = sell, buy
    end
    
    # Sell price, MtGox#currency per bitcoin.
    attr_reader :sell
    
    # Buy price, MtGox#currency per bitcoin.
    attr_reader :buy
    
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
