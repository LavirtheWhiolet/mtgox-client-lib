require 'pshash'
require 'utils'


# Model of the exchange.
# 
# Remark: don't forget to #close() the Exchange after you have finished
# using it!
#
# TODO: This class and its subclasses need more functionality.
# 
class Exchange
  
  # Current Ticker.
  # 
  # Abstract.
  # 
  def ticker
    abstract
  end
  
  # Ticker next after current (this method waits for the Ticker change).
  # 
  # Abstract.
  # 
  def next_ticker
    abstract
  end
  
  #
  # frees all system resources grabbed by this Exchange, i. e. closes
  # all connections, frees all mutexes etc. The instance remains usable
  # but further operations require extra time to grab the freed resources again.
  #
  # Abstract.
  # 
  def close()
    abstract
  end
  
  # ISO-4217 code of the currency this exchange works with.
  # 
  # Abstract.
  # 
  def currency
    abstract
  end
  
  # ISO-4217 code of the item which is bought/sold at this exchange.
  # 
  # Abstract.
  # 
  def item
    abstract
  end
  
  # returns VirtualClient.
  # 
  # +virtual_account_filename+ is name of file where the returned
  # VirtualClient's account will be stored.
  # 
  # Abstract.
  # 
  def virtual_client(virtual_account_filename)
    abstract
  end
  
  # Not inheritable.
  class Ticker
    
    def initialize(sell_price, buy_price)
      @sell_price, @buy_price = sell_price, buy_price
    end
    
    # Sell price, Exchange#currency per Exchange#item.
    attr_reader :sell_price
    
    alias sell sell_price
    
    # Buy price, Exchange#currency per Exchange#item.
    attr_reader :buy_price
    
    alias buy buy_price
    
    def to_s
      "Sell: #{sell.to_f} Buy: #{buy.to_f}"
    end
    
    def == other
      self.class == other.class &&
      self.sell_price == other.sell_price &&
      self.buy_price == other.buy_price
    end
    
    alias eql? ===
    
  end
  
  class VirtualClient
    
    # Accessible to Exchange only.
    def initialize(virtual_account_filename, exchange)
      @account_filename = account_filename
      @exchange = exchange
      #
      @account = nil
    end
    
    # Exchange this VirtualClient is client of.
    attr_reader :exchange
    
    # Commission effective for this VirtualClient.
    # 
    # Abstract.
    # 
    def commission
      abstract
    end
    
    # This VirtualClient's account balance in the form of Hash.
    def balance
      with_account { account.dup }
    end
    
    def reset_account
      PSHash.delete(@account_filename)
    end
    
    # deposits +amount+ of currency used at #exchange to this
    # VirtualClient's account.
    def deposit(amount)
      raise ArgumentError, %Q{can not deposit negative amount of #{exchange.currency} to account} if amount < 0
      #
      position = exchange.currency
      with_account { account[position] ||= 0; account[position] += amount }
    end
    
    # buys +amount+ of Exchange's items at specified price. If the
    # VirtualClient doesn't have enough money then they are taken from some
    # virtual creditor (with zero commission) and the debt is written to your
    # account.
    # 
    # This operation may take long time to complete (as the VirtualClient
    # may wait until the market price reaches the requested one). If
    # +on_ticker_change+ is given then it is called each time
    # Exchange#ticker changes.
    # 
    def buy(amount, price = exchange.ticker.sell_price, &on_ticker_change)
      raise ArgumentError, %Q{can not buy negative amount of #{exchange.item}} if amount < 0
      #
      once do
        # Wait until sell price will be appropriate.
        if exchange.ticker.sell_price > price then
          exchange.next_ticker
          on_ticker_change.call() if on_ticker_change
          redo
        end
        # Buy!
        with_account do
          # Prepare positions.
          account[exchange.item] ||= 0
          account[exchange.currency] ||= 0
          # Buy!
          account[exchange.currency] -= (amount * exchange.ticker.sell_price) * (1 + commission)
          account[exchange.item] += amount
        end
      end
    end
    
    # sells amount of Exchange's items at specified price. If the VirtualClient
    # doesn't have enough items then they are taken from some virtual
    # creditor (with zero commission) and the debt is written to the
    # VirtualClient's account.
    # 
    # This operation may take long time to complete (as this method may wait
    # for appropriate offers at #exchange). If +on_ticker_change+ is given then
    # it is called every time Exchange#ticker changes.
    # 
    def sell(amount, price = exchange.ticker.buy_price, &on_ticker_change)
      raise ArgumentError, %Q{can not sell negative amount of #{exchange.item}} if amount < 0
      #
      once do
        # Wait for appropriate offers.
        if exchange.ticker.buy_price < price then
          exchange.next_ticker
          on_ticker_change.call() if on_ticker_change
          redo
        end
        # Sell!
        with_account do
          # Prepare positions.
          account[exchange.item] ||= 0
          account[exchange.currency] ||= 0
          # Sell!
          account[exchange.item] -= amount
          account[exchange.currency] += (amount * exchange.ticker.buy_price) * (1 - commission)
        end
      end
    end
    
    private
    
    # See #account.
    def with_account(&block)
      PSHash.open(@account_filename) do |account|
        @account = account
        begin
          yield
        ensure
          @account = nil
        end
      end
    end
    
    # Virtual account of this VirtualClient in the form of PSHash.
    # 
    # This method is valid only inside block passed to #with_account().
    # 
    def account
      @account or raise %Q{Invalid usage; see method's documentation}
    end
    
  end
  
end
