__END__
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
