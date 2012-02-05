require 'requirements'
require 'mathn'
require 'fileutils'


# Persistent.
class VirtualWallet
  
  DEFAULT_FILENAME = `echo $HOME/.virtual-wallet`.strip
  
  def self.[](filename)
    new(filename)
  end
  
  def self.default
    self[DEFAULT_FILENAME]
  end
  
  private_class_method :new
  
  def initialize(filename)
    @filename = filename
    @content =
      if File.exist?(filename) then File.open(@filename, "rb") { |io| Marshal.load(io) }
      else new_content; end
  end
  
  # +currency+ is ISO-4217 code of currency.
  def [](currency)
    @content[currency]
  end
  
  # See also #[].
  def []=(currency, amount)
    #
    @content[currency] = amount
    #
    File.open(@filename, "wb") { |io| Marshal.dump(@content, io) } if amount != 0
  end
  
  def clear()
    @content = new_content
    FileUtils.rm_f @filename
    return self
  end
  
  private
  
  def new_content()
    Hash.new { |hash, key| hash[key] = 0 }
  end	
  
end
