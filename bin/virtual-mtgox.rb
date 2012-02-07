require 'requirements'
require 'mtgox'
require 'mathn'
require 'string/to_rational'
require 'facets/string/indent'
require 'erb'


# ---- Private Lib ----


# Persistent. Safe for access from multiple processes.
# 
# It also may be considered as map from item name to amount of the item.
# 
class VirtualAccount
  
  DEFAULT_FILENAME = "#{ENV["HOME"]}/.virtual-mtgox-account"
  
  include Enumerable
  
  private_class_method :new
  
  class << self
  
    # opens VirtualAccount stored in specified file and passes it to +block+.
    # If the file does not exist then new VirtualAccount is created.
    # 
    # No other process may access the VirtualAccount until this operation
    # terminates.
    # 
    def open(filename, &block)
      # Grab lock.
      File.open(filename + ".lock", "w") do |lockfile|
        lockfile.flock(File::LOCK_EX)
        # Read content (or create new one).
        content =
          if File.exist? filename then File.open(filename, "rb") { |file| Marshal.load(file) }
          else new; end
        begin
          #
          return yield(content)
        ensure
          # Save content (anyway).
          File.open(filename, "wb") { |file| Marshal.dump(content, file) }
        end
      end  
    end
    
    # closes VirtualAccount stored in specified file (in financial sense).
    def close(filename)
      # Grab lock.
      File.open(lockfilename = filename + ".lock", "w") do |lockfile|
        lockfile.flock(File::LOCK_EX)
        # Delete everything!
        File.delete filename if File.exist? filename
        File.delete lockfilename
      end
    end
    
    alias delete close
    
  end
  
  def initialize()
    @content = Hash.new
  end
  
  # adds +amount+ of +item+ to this VirtualAccount.
  def deposit(item, amount)
    @content[item] ||= 0
    @content[item] += amount
  end
  
  # withdraws +amount+ of +item+ from this VirtualAccount.
  def withdraw(item, amount = :all)
    # Parse args.
    if amount == :all then amount = @content[item] || 0; end
    # Withdraw!
    @content[item] ||= 0
    raise %Q{Insufficient funds: #{amount} #{item} is required but you have #{@content[item].to_f} #{item} only} if amount > @content[item]
    @content[item] -= amount
  end
  
  # Amount of +item+ this VirtualAccount has.
  def [](item)
    @content[item] || 0
  end
  
  def each
    @content.each_pair do |item, amount|
      yield item, amount
    end
  end
  
  def to_human_readable_yaml
    self.map { |item, amount| "#{item}: #{amount.to_f}" }.join("\n")
  end
  
  alias to_hr_yaml to_human_readable_yaml
  
end


class VirtualClient
  
  include Enumerable
  
  # 
  # +account_filename+ will be used to open VirtualAccount. See
  # VirtualAccount#open() for details. It may be omitted only if you are
  # not going to use VirtualClient's methods which need your VirtualAccount.
  # 
  # +log+ is IO.
  # 
  def initialize(exchange, account_filename = nil, log = STDERR)
    @account_filename = account_filename
    @exchange = exchange
    @log = log
    #
    @account = nil
  end
  
  begin
    @@descriptions = ""
  end
  
  # Private.
  # 
  # It describes next method as if the description would be printed by
  # "--help" command line argument.
  # 
  # +description+ is an ERB template in which you may use instance methods
  # of the VirtualClient.
  # 
  def self.desc(description)
    @@descriptions << description.rstrip << "\n\n"
  end
  
  # Description of methods of this VirtualClient in the form suitable for
  # printing by "--help" command line argument.
  def help
    ERB.new(@@descriptions).result(binding)
  end
  
  desc <<-TEXT
    add-funds amount
        Just adds +amount+ of <%=exchange.currency%> to your account. If the
        account does not exist then it is created.
  TEXT
  def add_funds(amount)
    amount = arg_to_rational(amount)
    #
    with_account do
      account.deposit(exchange.currency, amount)
      log_yaml(
        "subject: #{amount} #{exchange.currency} appeared in your account from nowhere",
        balance_yaml_entry
      )
    end
  end
  
  desc <<-TEXT
    close-account
        Closes your account - all funds are removed, all debts are written off
        etc.
  TEXT
  def close_account()
    VirtualAccount.close(@account_filename)
    log_yaml("subject: account closed")
  end
  
  desc <<-TEXT
    info
        Prints information about your account.
  TEXT
  def info
    with_account do
      puts balance_yaml_entry
      puts "commission: #{(commission * 100).to_f}%"
    end
  end
  
  desc <<-TEXT
    buy amount [price]
        Buys +amount+ of <%=exchange.item%> for +price+ <%=exchange.currency%> per <%=exchange.item%>.
        If price is not specified then <%=exchange.item%> are bought at
        market price.
  TEXT
  def buy(amount, price = exchange.ticker.sell_price)
    amount = arg_to_rational(amount)
    price = if price.is_a? Numeric then price else arg_to_rational(price); end
    # Wait until the price reaches requested one.
    until exchange.ticker.sell_price <= price
      log_yaml(
        "ticker: {sell: #{exchange.ticker.sell.to_f}, buy: #{exchange.ticker.buy.to_f}}",
        "waiting for: sell <= #{price.to_f}"
      )
      exchange.next_ticker
    end
    # Buy!
    with_account do
      actual_price = exchange.ticker.sell_price * (1 + commission)
      account.withdraw exchange.currency, amount * actual_price
      account.deposit exchange.item, amount
      log_yaml(
        "subject: bought #{amount.to_f} #{exchange.item} for #{actual_price.to_f} #{exchange.currency}/#{exchange.item}",
        balance_yaml_entry
      )
    end
  end
  
  desc <<-TEXT
    ticker
        Prints current ticker.
  TEXT
  def ticker
    puts "{sell: #{exchange.ticker.sell.to_f}, buy: #{exchange.ticker.buy.to_f}}"
  end

  private
  
  def arg_to_rational(arg)
    arg.to_rational(:or_nil) or raise ArgumentError,%Q{#{arg} is not a floating point number}
  end
  
  # writes message in YAML format to @log.
  # 
  # +entries+ are YAML entries of the message (in the form of String-s,
  # for example: "item: value", "ticker: {sell: 10, buy: 20}").
  # 
  def log_yaml(*entries)
    @log.puts "---"
    @log.puts "time: #{Time.now}"
    entries.each { |entry| @log.puts entry }
  end
  
  # Macro. See source code.
  def balance_yaml_entry()
    "balance:\n" +
      account.to_hr_yaml.indent(2)
  end
  
  # Commission effective for this VirtualClient.
  def commission
    "0.6".to_rational / 100
  end
  
  # See #account.
  def with_account(&block)
    VirtualAccount.open(@account_filename) do |account|
      @account = account
      begin
        yield
      ensure
        @account = nil
      end
    end
  end
  
  # VirtualAccount associated with this VirtualClient.
  # 
  # This method is valid only inside block passed to #with_account().
  # 
  def account
    @account or raise %Q{Invalid use of this method; see doc.}
  end
  
  # Exchange this VirtualClient is client of.
  def exchange
    @exchange
  end
  
end


# ----

# Setup.
exchange = MtGox.instance  # It is virtual *Mt. Gox* client, isn't it?

# Print help (if needed).
if %W{-h --help}.include?(ARGV[0]) or ARGV.empty? then
  puts <<-HELP
Virtual Mt. Gox client

Usage:  virtual-mtgox -h|--help
        virtual-mtgox [operation] [args]

First form prints this help. Second form performs specified operation with
specified arguments. Supported operations are described below.

Operations

#{VirtualClient.new(exchange).help.rstrip}

Environment Variables

    VIRTUAL_MTGOX_ACCOUNT_FILE
        Name of file where the virtual account will be stored. By default it
        is `VirtualAccount::DEFAULT_FILENAME'.

HELP
  exit
end

# Parse args and environment variables.
raise ArgumentError, %Q{No operation specified} if ARGV.length < 1
op = ARGV[0].gsub('-', '_').to_sym
args = ARGV[1..-1]
account_filename = ENV["VIRTUAL_MTGOX_ACCOUNT_FILE"] || VirtualAccount::DEFAULT_FILENAME
log = STDERR
# Perform the operation!
VirtualClient.new(MtGox.instance, account_filename, log).__send__ op, *args
