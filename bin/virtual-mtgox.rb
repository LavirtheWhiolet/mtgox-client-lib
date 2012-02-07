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
  
  # passes +block+ with the opened VirtualAccount. No other process may
  # access the VirtualAccount until this operation terminates. The
  # VirtualAccount is saved after the +block+ terminates. 
  def self.open(filename, &block)
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
  
  def self.delete(filename)
    # Grab lock.
    File.open(lockfilename = filename + ".lock", "w") do |lockfile|
      lockfile.flock(File::LOCK_EX)
      # Delete everything!
      File.delete filename if File.exist? filename
      File.delete lockfilename
    end
  end
  
  def to_yaml
    self.map { |item, amount| "#{item}: #{amount}" }.join("\n")
  end
  
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
        Just adds `amount' of <%=exchange.currency%> to your account.
  TEXT
  def add_funds(amount)
    amount = arg_to_rational(amount)
    #
    with_account do
      @account.deposit(exchange.currency, amount)
      log_yaml("subject: #{amount} #{exchange.currency} appeared in your account from nowhere", balance_log)
    end
  end
  
  desc <<-TEXT
    clear-account
        Removes all funds from your account.
  TEXT
  def clear_account()
    VirtualAccount.delete(@account_filename)
    log_yaml("subject: account cleared")
  end
  
  desc <<-TEXT
    info
        Prints information about your account.
  TEXT
  def info
    with_account do
      puts "balance:\n" +
        @account.to_yaml.indent(2)
      puts "commission: #{(commission * 100).to_f}%"
    end
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
  
  # Account balance in format suitable for #log_yaml(). The account must
  # be opened (see #with_account()).
  # 
  def balance_log()
    "balance:\n" +
      @account.to_yaml.indent(2)
  end
  
  # Commission effective for this VirtualClient.
  def commission
    "0.6".to_rational / 100
  end
  
  # opens account (with VirtualAccount#open()), sets <code>@account</code>
  # to it and runs +block+. <code>@account</code> is set back to +nil+ after
  # this operation.
  # 
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
