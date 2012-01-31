require 'rubygems'
gem 'facets'
gem 'faraday'
gem 'web-socket-ruby'
require 'uri'
require 'faraday'
require 'utils'
require 'web_socket'
require 'monitor'

# TODO: Transports must be just transports. They must transfer data only.
# TODO: Swap arguments in messages. Data must go first.

# Implementation of Socket.IO (see http://socket.io/), client side.
# 
# It is thread-safe.
# 
class Socket_IO

  private_class_method :new

  # 
  # returns new Socket_IO connected to specified address.
  # 
  # +uri+ must be of the following form:
  # <code>[scheme] '://' [host] '/' [namespace] '/'</code>.
  #
  def self.open(uri)
    # Normalize arg.
    uri.chomp! '/'
    # Handshake.
    handshake_response = Faraday.post "#{uri}/1/"
    raise %Q{Can not connect to #{uri}; response status: #{handshake_response.status}} unless handshake_response.status == 200
    session_id, heartbeat_timeout, connection_closing_timeout, supported_transports =
      handshake_response.body.split(':')
    heartbeat_timeout = if heartbeat_timeout.empty? then nil else heartbeat_timeout.to_i; end
    # Open transport.
    case supported_transports
    when /websocket/
      uri = URI.parse(uri)
      transport_uri_scheme =
        case uri.scheme
        when "http" then "ws"
        when "https" then "wss"
        else raise %Q{"#{uri.scheme}" scheme is not supported yet}
        end
      WebSocketTransport.new(
        "#{transport_uri_scheme}://#{uri.host}#{uri.path}/1/websocket/#{session_id}",
        heartbeat_timeout
      )
    else
      raise %Q{None of these transports are implemented yet: #{transports}}
    end
  end
  
  # +message+ is Message.
  def send(message)
    abstract
  end
  
  # returns Message.
  def receive()
    abstract
  end
  
  # Alias for #receive().
  def recv(); receive(); end
  
  # Alias for #send().
  def write(message); send(message); end
  
  # Alias for #receive().
  def read(); receive(); end
  
  def close()
    abstract
  end
  
  # Message passed through Socket_IO.
  class Message
    
    # Used by this class and its subclasses only.
    # 
    # Map from subclass's #type to the subclass as such.
    # 
    SUBCLASSES = {}
    
    class << self
      
      alias [] new
      
      # Used by Socket_IO and its internal subclasses only.
      # 
      # It decodes Message encoded according to
      # https://github.com/LearnBoost/socket.io-spec, "Messages" section,
      # "Encoding" subsection.
      # 
      def decode(encoded_message)
        # 
        type, id, endpoint, data = encoded_message.split(':', 4)
        # 
        (SUBCLASSES[type] or UnknownMessage).new(id, endpoint, data, type)
      end
      
    end
    
    # Used by this class and its subclasses only.
    # 
    # It registers this class in SUBCLASSES and redefines #type appropriately.
    # 
    def self.type(type)
      # Register.
      SUBCLASSES[type.to_s] = self
      # Redefine #type.
      eval "def type; '#{type}'; end"
    end
    
    def initialize(id, endpoint, data, ignored = nil)
      @id, @endpoint, @data = id, endpoint, data
    end
    
    # Used by Socket_IO and its internal classes only.
    def type
      abstract
    end
    
    # Used by Socket_IO and its internal classes only.
    # 
    # An opposite to Message.decode().
    # 
    def encode()
      "#{type}:#{id}:#{endpoint}:#{data}"
    end
    
    # Alias for #encode().
    def encoded(); encode(); end
    
    attr_reader :id
    attr_reader :endpoint
    attr_reader :data
    
  end
  
  class UnknownMessage < Message
    
    def initialize(id, endpoint, data, type)
      super(id, endpoint, data)
      @type = type
    end
    
    attr_reader :type
    
  end
  
  private
  
  class Disconnect < Message; type 0; end
  class Connect < Message; type 1; end
  class Heartbeat < Message; type 2; end
  
  # It is thread-safe.
  class WebSocketTransport < Socket_IO
    
    include MonitorMixin
    
    public_class_method :new
    
    # 
    # +uri+ is URI to connect to (in the form of String).
    # 
    # +heartbeat_timeout+ is number of seconds or +nil+ if heartbeat is
    # not required.
    # 
    def initialize(uri, heartbeat_timeout)
      heartbeat_needed = (heartbeat_timeout != nil)
      #
      @transport = WebSocket.new(uri)
      #
      @heartbeat =
        if heartbeat_needed then
          #  TODO
        end
        Thread.new do
          loop do
            
            begin; sleep(heartbeat_timeout - 1); rescue; break; end
            send Heartbeat[]
          end
        end
      end
    end
    
    def send(message)
      synchronize do
        @transport.send message.encode()
      end
    end
    
    def receive()
      synchronize do
        once do
          # Read the message as such.
          message = Message.decode(@transport.receive())
          # Skip TODO
          redo if message.is_a?(Heartbeat) or message.is_a?(Connect)
          
        end
      end
    end
    
  end
  
  
  
end

#Socket_IO.open 'https://socketio.mtgox.com/socket.io'
puts Socket_IO::Message.decode("2:::::::")
