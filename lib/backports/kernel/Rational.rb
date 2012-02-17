if RUBY_VERSION < '1.9.1'

require 'strscan'
require 'mathn'


alias __old_Rational__ Rational

def Rational(*args)
  #
  return __old_Rational__(*args) unless args.size == 1
  arg = args[0]
  #
  case arg
  when Float
    # Algorithm is taken from http://markmail.org/message/nqgrsmaixwbrvsno.
    if arg.nan?
      return Rational(0,0) # Div by zero error
    elsif arg.infinite?
      return Rational(arg<0 ? -1 : 1,0) # Div by zero error
    end
    s,e,f = [arg].pack("G").unpack("B*").first.unpack("AA11A52")
    s = (-1)**s.to_i
    e = e.to_i(2)
    if e.nonzero? and e<2047
      Rational(s)*Rational(2)**(e-1023)*Rational("1#{f}".to_i(2),0x10000000000000)
    elsif e.zero?
      Rational(s)* Rational(2)**(-1024)*Rational("0#{f}".to_i(2),0x10000000000000)
    end
  when String
    # Init parsing.
    str = StringScanner.new(arg)
    str.skip(/ */)
    error_occured = false
    # Grammar.
    error = lambda do |return_value|
      str.terminate()
      error_occured = true
      return return_value
    end
    int = lambda do |may_not_be_empty|
      result1 = str.scan(/[0-9_]*/)
      return error[0] if result1.empty? and may_not_be_empty
      return error[0] if result1[0] == ?_ or result1[-1] == ?_
      return result1.to_i
    end
    sign = lambda do
      (str.scan(/[\-\+]?/) == '-') ? (-1) : (+1)
    end
    float = lambda do
      integer_part = sign[] * int[false]
      fractional_part = 0
      if str.scan(/\./) then
        fractional_part = int[true]
      end
      mantissa = Rational(
        (integer_part.to_s + fractional_part.to_s).to_i,
        ("1" + "0" * fractional_part.to_s.length).to_i
      )
      exponent = 0
      if str.scan(/[eE]/) then
        exponent = sign[] * int[true]
      end
      return mantissa * 10.to_r ** exponent
    end
    # Parse!
    result = float[]
    if str.scan(/\//) then
      result /= float[]
    end
    # Check whether parsing has finished without errors.
    str.skip(/ */)
    if not str.eos? or error_occured then raise ArgumentError, %Q{invalid value for convert: #{arg.inspect}}; end
    # 
    return result
  else
    __old_Rational__(arg)
  end
end

  
end
