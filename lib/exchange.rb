require 'requirements'
require 'mathn'
require 'pshash'
require 'once'
require 'abstract'
require 'erb'
require 'backports/kernel/Rational'
require 'string/indent_to'
require 'strscan'
require 'facets/string/indent'
require 'facets/kernel/in'
require 'facets/denumerable'
require 'facets/module/is'
require 'numeric/to_s_with_plus'


# Model of the exchange.
# 
# Remark: don't forget to #close() the Exchange after you have finished
# using it!
# 
# TODO: This class and its subclasses need more functionality.
# 
class Exchange
  
  # Abstract.
  def name
    abstract
  end
  
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
  
  # All Ticker-s next after current (the returned collection waits for
  # every Ticker it is requested for).
  # 
  # See also #next_ticker.
  # 
  def next_tickers
    NextTickers.new(self)
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
  # +virtual_account_filename+ is name of file where the VirtualClient's
  # account will be stored.
  # 
  # Abstract.
  # 
  def virtual_client(virtual_account_filename)
    abstract
  end
  
  # Not inheritable.
  class Ticker
    
    class << self
      
      alias [] new
      
    end
    
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
  
  class NextTickers
    
    is Denumerable
    
    def initialize(exchange)
      @exchange = exchange
    end
    
    def each
      yield @exchange.next_ticker while true
    end
    
  end
  
  class VirtualClient
    
    # Accessible to Exchange only.
    # 
    # Overridable.
    # 
    def initialize(virtual_account_filename, exchange)
      @account_filename = virtual_account_filename
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
    
    # (app. operation, see #app_operations_description)
    # 
    # Print info about your account, commission etc.
    # 
    def info()
      puts balance_to_yaml
      puts "commission: #{(commission * 100).to_f}%"
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Reset your account - remove all funds, write off all debts etc.
    # 
    def reset_account
      PSHash.delete(@account_filename)
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Deposit +amount+ of +item+ to your account. Default +item+ is <%=exchange.currency%>.
    # 
    def deposit(amount, item = exchange.currency)
      amount = Rational(amount)
      raise ArgumentError, %Q{can not deposit negative amount of #{exchange.currency} to account} if amount < 0
      #
      position = item
      with_account { account[position] ||= 0; account[position] += amount }
      #
      log(
        balance_to_yaml(position => amount)
      )
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Wait until current exchange rate (Ticker) changes.
    # 
    def wait_ticker_change()
      exchange.next_ticker
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # The same as #wait_ticker_change.
    # 
    def wait()
      wait_ticker_change()
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Buy +amount+ of <%=exchange.item%> for +price+ (<%=exchange.currency%> per <%=exchange.item%>). If the price is
    # not specified then current market price is used.
    # 
    # If there is no enough money in your account then the money is
    # borrowed from some virtual creditor (with zero commission) and
    # the debt is written to your account.
    # 
    # This operation may take long time to complete (as the client
    # may wait until the market price reaches the requested one).
    # 
    def buy(amount, price = exchange.ticker.sell_price)
      amount = Rational(amount)
      raise ArgumentError, %Q{can not buy negative amount of #{exchange.item}} if amount < 0
      price = Rational(price)
      # 
      wait until exchange.ticker.sell_price <= price 
      # Buy!
      money_spent = nil
      with_account do
        # Prepare positions.
        account[exchange.item] ||= 0
        account[exchange.currency] ||= 0
        # Buy!
        account[exchange.currency] -= (money_spent = (amount * exchange.ticker.sell_price) * (1 + commission))
        account[exchange.item] += amount
      end
      #
      log(
        "---",
        "time: #{Time.now}",
        "operation: buy",
        "ticker: {buy: #{exchange.ticker.buy.to_f}, sell: #{exchange.ticker.sell.to_f}}",
        balance_to_yaml(
          exchange.currency => -money_spent,
          exchange.item => +amount
        )
      )
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Sell +amount+ of <%=exchange.item%> for +price+ <%=exchange.currency%> per <%=exchange.item%>. If the +price+ is
    # not specified then current market price is used.
    # 
    # If there is no enough <%=exchange.item%> in your account then they are borrowed
    # from some virtual creditor (with zero commission) and the debt
    # is written to your account.
    # 
    # This operation may take long time to complete (as this method may wait
    # for appropriate offers at "<%=exchange.name%>").
    # 
    def sell(amount, price = exchange.ticker.buy_price)
      amount = Rational(amount)
      raise ArgumentError, %Q{can not sell negative amount of #{exchange.item}} if amount < 0
      price = Rational(price)
      # 
      wait until exchange.ticker.buy_price >= price
      # Sell!
      money_gained = nil
      with_account do
        # Prepare positions.
        account[exchange.item] ||= 0
        account[exchange.currency] ||= 0
        # Sell!
        account[exchange.item] -= amount
        account[exchange.currency] += (money_gained = (amount * exchange.ticker.buy_price) * (1 - commission))
      end
      #
      log(
        "---",
        "time: #{Time.now}",
        "operation: sell",
        "ticker: {buy: #{exchange.ticker.buy.to_f}, sell: #{exchange.ticker.sell.to_f}}",
        balance_to_yaml(
          exchange.currency => +money_gained,
          exchange.item => -amount
        )
      )
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # Execute Ruby +script+ in context of Exchange::VirtualClient.
    # See documentation for Exchange::VirtualClient for details.
    # 
    def exec(script)
      eval script, binding
    end
    
    # (app. operation, see #app_operations_description)
    # 
    # The same as #exec but +script+ is read from +file+.
    # 
    def exec_file(file)
      exec(File.read(file))
    end
    
    # runs this VirtualClient as if it were a standalone application (with
    # ARGV, STDIN, STDOUT etc.).
    def run_as_app()
      begin
        # Help.
        if ARGV[0].in?(%W{-h --help}) or ARGV.empty? then
          puts ERB.new(HELP_TEMPLATE).result(binding)
          return
        end
        # Parse args.
        op = ARGV.shift.gsub("-", "_").to_sym
        args = ARGV
        # Perform the op.!
        __send__ op, *args
      ensure
        exchange.close()
      end
    end
    
    private
    
    # 
    # forwards all unknown methods to #exchange or its Exchange#ticker.
    # Good for scripting.
    # 
    # See also #exec(), #exec_file().
    # 
    def method_missing(method_id, *args, &block)
      if exchange.respond_to? method_id
        exchange.__send__ method_id, *args, &block 
      elsif exchange.ticker.respond_to? method_id
        exchange.ticker.__send__ method_id, *args, &block
      else
        super(method_id, *args, &block)
      end
    end
    
    # writes +lines+ to log.
    def log(*lines)
      lines.each { |line| STDERR.puts line }
    end
    
    # 
    # collects all methods having
    # "(app. operation, see #app_operations_description)" first line
    # in their built-in documentation (which should be in RDoc format), and
    # converts them to form suitable for printing by "-h" or "--help" command
    # line key.
    # 
    # The documentation collected may have ERB tags. They are opened according
    # to ERB rules.
    # 
    # Remark: Currently RDoc directives (such as <code>:call-seq:</code>,
    # <code>:nodoc:</code> etc.) are not supported.
    # 
    # See also #run_as_app().
    # 
    def app_operations_description
      result = ""
      # 
      this_file = StringScanner.new(File.read(__FILE__))
      while true
        # Find next doc.
        this_file.skip_until(/\#\s+\(app\. operation\, see \#app_operations_description\)/) or break
        # Extract the doc parts.
        rdoc = this_file.scan_until(/ def /).chomp('def').strip
        call = this_file.scan_until(/\n/).strip
        # Execute the doc as ERB template.
        rdoc = ERB.new(rdoc).result(binding)
        # Convert the doc parts to "help" format.
        call = call.
          # Convert arguments with default values to "[arg]" form.
          gsub(/([a-z][a-zA-Z0-9_]+)\s*\=\s*.*?[\,\)\n]/, "[\\1]").
          # Remove all parentheses and commas.
          gsub(/[\(\)]/, ' ').gsub(',', '').
          # Convert "_" to "-" in method name.
          gsub(/^([^ ]+)/) { |function_name| function_name.gsub("_", "-") }.
          # Clean up.
          squeeze(' ')
        doc = rdoc.
          # Remove lines excluded from documentation (according to RDoc rules).
          gsub(/\#\-+\n.*?\#\++\n/m, '').
          # Convert to "help" format.
          lines.map { |line| line[/^\s*\# ?(.*)/m, 1] or "" }.join.strip
        # Put final description into result.
        result <<
          call << "\n" <<
          doc.indent(4) << "\n\n"
      end
      # 
      return result.rstrip      
    end
    
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
    
    # Macro. It returns #balance in human-readable YAML format.
    # 
    # +changes+ is map from account's position to its change.
    # 
    def balance_to_yaml(changes = {})
      "balance:\n" +
        balance.map do |position, amount|
          "  #{position}: #{amount.to_f}" +
            if (change = changes[position]) != nil then
              " (#{change.to_f.to_s_with_plus})"
            else
              "" 
            end
        end.join("\n")
    end

  end
  
end


# Private for Exchange::VirtualClient. It is hear just because of readability.
HELP_TEMPLATE = <<ERB
Virtual <%=exchange.name%> client.

Usage: <%=$0%> [-h|--help]
       <%=$0%> op args

First form prints this help. Second form performs `op' passing `args' to it.
Supported `op'-s (with their `args') are following:

<%= app_operations_description.indent(4) %>

ERB
