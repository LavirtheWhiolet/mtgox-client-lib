require 'exchange.rb'


class PseudoExchange < Exchange
  
  def initialize(item, currency)
    @ticker = nil
    @item = item
    @currency = currency
  end
  
  def name
    "Pseudo Exchange"
  end
  
  def 
  
  def ticker
    @ticker or raise %(Ticker is not set yet)
  end
  
  def next_ticker
    raise %(Not implemented)
  end
  
  def close()
    # Do nothing.
  end
  
  def currency
    @currency
  end
  
  def item
    @item
  end
  
  def virtual_client(virtual_account_filename, commission = 0.0)
    VirtualClient.new(virtual_account_filename, self, commission)
  end
  
  private
  
  class VirtualClient < Exchange::VirtualClient
    
    def initialize(virtual_account_filename, exchange, commission)
      super(virtual_account_filename, exchange)
      #
      self.commission = commission
    end
    
    def commission
      @commission
    end
    
    def commission=(value)
      @commission = Rational(value)
    end
    
  end
  
end
