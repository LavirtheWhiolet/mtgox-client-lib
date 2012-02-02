require 'rubygems'
gem 'facets'
gem 'faraday'
gem 'web-socket-ruby'
gem 'json'
require 'uri'
require 'faraday'
require 'utils'
require 'web_socket'
require 'monitor'
require 'facets/integer/of'
require 'reentrant_mutex'
require 'json'


# Implementation of client-side Socket.IO (see http://socket.io/).
# 
# Remark: heartbeats are maintained by Socket_IO automatically so you don't
# need to send them explicitly.
# 
# Thread-safe.
# 
# Not inheritable.
# 
class Socket_IO
  
  # For any heartbeat timeout given by server the Socket_IO sends "heartbeat"
  # messages every (heartbeat timeout minus HEARTBEAT_TIMEOUT_DIFF) seconds.
  HEARTBEAT_TIMEOUT_DIFF = 2
  
  private_class_method :new
  
  # 
  # returns new Socket_IO connected to specified address.
  # 
  # +uri+ must be of the following form:
  # <code>[scheme] '://' [host] '/' [namespace] '/'</code>.
  #
  def self.open(uri)
    new(uri)
  end
  
  def initialize(uri)  # :nodoc:
    # Normalize arg.
    uri.chomp! '/'
    # Handshake.
    handshake_response = Faraday.post "#{uri}/1/"
    raise IOError, %Q{Can not connect to #{uri}; response status: #{handshake_response.status}} unless handshake_response.status == 200
    session_id, heartbeat_timeout_str, connection_closing_timeout_str, supported_transports =
      handshake_response.body.split(':')
    heartbeat_needed = (not heartbeat_timeout_str.empty?)
    if heartbeat_needed
      heartbeat_period = heartbeat_timeout_str.to_i - HEARTBEAT_TIMEOUT_DIFF
      raise IOError, %Q{Server requests too frequent heartbeat: #{heartbeat_timeout} s.} unless heartbeat_period > 0
    end
    # Open transport.
    # NOTE: The transport must conform to Socket_IO::Transport interface.
    @transport =
      case supported_transports
      when /websocket/
        uri = URI.parse(uri)
        transport_uri_scheme =
          case uri.scheme
          when "http" then "ws"
          when "https" then "wss"
          else raise %Q{"#{uri.scheme}" scheme is not supported yet}
          end
        WebSocket.new(
          "#{transport_uri_scheme}://#{uri.host}#{uri.path}/1/websocket/#{session_id}"
        )
      else
        raise %Q{Server supports following transports: #{transports}; but none of them are implemented yet}
      end
    # Synchronize on transport ends.
    @input_mutex = ReentrantMutex.new
    @output_mutex = ReentrantMutex.new
    # -- At this moment the socket is fully functional. One
    # -- may send and receive messages over it.
    # Start heartbeat (if needed).
    if heartbeat_needed
      @heartbeat_stopped = false  # This variable is not synchronized anyhow because it is not needed.
      @heartbeat = Thread.new do
        until @heartbeat_stopped
          send Heartbeat[]
          sleep(heartbeat_period)
        end
      end
    end
  end
  
  # +message+ is Message.
  def send(message)
    raise %Q{message Must be #{Message} but #{message.inspect} is given} unless message.is_a? Message
    #
    @output_mutex.synchronize do
      #
      raise_closed_stream_error if closed?(@output_mutex)
      # 
      @transport.send message.encoded
    end
  end
  
  alias write send
  
  # returns Message.
  def receive()
    @input_mutex.synchronize do
      once do
        #
        raise_closed_stream_error if closed?
        # Receive next frame.
        received = @transport.receive()
        if received.nil? then close(); redo; end
        # 
        message = Message.decode(received)
        # Intercept and process service messages. Client does not need them.
        case message
        when Heartbeat then redo
        when Disconnect then
          # If endpoint is not specified then this is "socket disconnected"
          # message.
          if message.endpoint.nil? or message.endpoint.empty? then close(); redo; end
        end
        #
        return message
      end
    end
  end
  
  alias recv receive
  
  alias read receive
  
  # :call-seq:
  #   closed?
  # 
  #--
  # mutex_to_use is used for optimization only. To accomplish its task this
  # method needs to lock either @input_mutex or @output_mutex. If you already
  # have any of them locked then you may specify it to this method to reduce
  # number of lockings.
  # 
  # See #close() source code for details.
  #++
  def closed?(mutex_to_use = @input_mutex)
    mutex_to_use.synchronize { @transport.nil? }
  end
  
  def close()
    @input_mutex.synchronize do @output_mutex.synchronize do
        #
        return if closed?
        # Stop heartbeat (if needed).
        if @heartbeat
          @heartbeat_stopped = true
          @heartbeat.wakeup
          @heartbeat.join
        end
        #
        send Disconnect[]
        # 
        @transport.close()
        # Mark this socket as closed. See #closed?() source code for details.
        @transport = nil
    end end
  end
  
  # Generic message described in
  # https://github.com/LearnBoost/socket.io-spec, "Messages" section.
  # 
  # For actual message see Msg.
  # 
  class Message
    
    class << self
      
      alias [] new
      
      # decodes Message encoded according to
      # https://github.com/LearnBoost/socket.io-spec, "Messages" section,
      # "Encoding" subsection.
      def decode(encoded_message)
        # 
        type, id, endpoint, data = encoded_message.split(':', 4)
        type = type.to_i
        # 
        (SUBCLASSES[type] or UnknownMessage).new(data, endpoint, id, type)
      end
      
    end
    
    # 
    # +data+ is value for #data.
    # 
    # +endpoint+ is value for #endpoint.
    # 
    # +id+ is value for #id.
    # 
    def initialize(data = "", endpoint = "", id = "", ignored = nil)
      @data, @endpoint, @id = data, endpoint, id
    end
    
    # An opposite to Message.decode().
    def encode()
      "#{type}:#{id}:#{endpoint}:#{data}"
    end
    
    # Alias for #encode().
    def encoded; encode(); end
    
    def type
      abstract
    end
    
    # String.
    attr_reader :id
    
    attr_reader :endpoint
    
    attr_reader :data
    
    def to_s
      return self.encoded
    end
    
    protected
    
    # Map from subclass's #type to the subclass as such.
    SUBCLASSES = 8.of { nil }
    
    # registers this class in SUBCLASSES and redefines #type appropriately.
    def self.type(type)
      # Register.
      SUBCLASSES[type] = self
      # Redefine #type.
      eval "class #{self}; def type; #{type}; end; end"
    end
    
  end
  
  # Signals disconnection.
  class Disconnect < Message; type 0; end
  
  # Only used for multiple sockets. Signals a connection to the endpoint.
  # Once the server receives it, it's echoed back to the client.
  class Connect < Message; type 1; end
  
  # A regular message.
  class Msg < Message; type 3; end
  
  # A JSON encoded message.
  class JSONMsg < Message
    
    type 4
    
    # 
    # +data+ may be JSON script or map.
    # 
    # See also Message#new().
    # 
    def initialize(data, endpoint = "", id = "", ignored = nil)
      #
      data = if data.is_a? String then JSON.parse(data); else data; end
      # 
      super(data, endpoint, id, ignored)
    end
    
    # It is always map (representable in JSON).
    # 
    # See also Message#data.
    # 
    def data; super; end
    
    # Alias to <code>data[key]</code>.
    def [](key)
      data[key]
    end 
    
    # See Message#encode().
    def encode()
      "#{type}:#{id}:#{endpoint}:#{data.to_json}"
    end
    
  end
  
  JSONMessage = JSONMsg
  
  # 
  # Like a JSONMessage, but has mandatory +name+ and +args+ fields.
  # +name+ is a String and +args+ is an Array.
  # 
  class Event < JSONMsg
    
    type 5
    
    # "name" field of #data.
    def name; data[:name] or data["name"]; end
    
    # "args" field of #data.
    def args; data[:args] or data["args"]; end
    
  end

  # An acknowledgment. It contains the message id as the message data.
  # If a "+" sign follows the message id, it's treated as an event message
  # packet.
  class ACK < Message; type 6; end
  
  class Error < Message; type 7; end
  
  # No operation. Used for example to close a poll after the polling
  # duration times out.
  class Noop < Message; type 8; end
  
  # Any other Message which is currently unknown to this implementation of
  # Socket.IO.
  class UnknownMsg < Message
    
    def initialize(data, endpoint, id, type)
      super(data, endpoint, id)
      @type = type
    end
    
    attr_reader :type
    
  end
  
  private
  
  def raise_closed_stream_error
    raise IOError, "closed stream"
  end
  
  class Heartbeat < Message; type 2; end
  
  # Thread-unsafe.
  module Transport
    
    # +data+ is data to send (in the form of String).
    def send(data)
      abstract
    end
    
    # returns data (in the form of String). It may return +nil+ if
    # the Transport is closed.
    def receive()
      abstract
    end
    
    def close()
      abstract
    end
    
  end
    
end


# When included, it adds all constants from Socket_IO to includer.
module Socket_IO_Constants
  
  for constant in Socket_IO.constants
    eval "#{constant} = ::Socket_IO::#{constant}"
  end
  
end

