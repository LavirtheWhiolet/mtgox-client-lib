if RUBY_VERSION < '1.9.1'

require 'rational'


class Float
  
  # Returns the value as a rational.
  # 
  # NOTE: 0.3.to_r isn't the same as '0.3'.to_r.  The latter is equivalent to
  # '3/10'.to_r, but the former isn't so.
  # 
  # For example:
  # 
  #   2.0.to_r    #=> (2/1)
  #   2.5.to_r    #=> (5/2)
  #   -0.75.to_r  #=> (-3/4)
  #   0.0.to_r    #=> (0/1)
  # 
  def to_r
    # Algorithm is taken from http://markmail.org/message/nqgrsmaixwbrvsno.
    if self.nan?
      return Rational(0,0) # Div by zero error
    elsif self.infinite?
      return Rational(self<0 ? -1 : 1,0) # Div by zero error
    end
    s,e,f = [self].pack("G").unpack("B*").first.unpack("AA11A52")
    s = (-1)**s.to_i
    e = e.to_i(2)
    if e.nonzero? and e<2047
      Rational(s)*Rational(2)**(e-1023)*Rational("1#{f}".to_i(2),0x10000000000000)
    elsif e.zero?
      Rational(s)* Rational(2)**(-1024)*Rational("0#{f}".to_i(2),0x10000000000000)
    end
  end
  
end


require 'strscan'                             

class String
  
  # Returns a rational which denotes the string form. The parser ignores
  # leading whitespaces and trailing garbage. Any digit sequences can be
  # separated by an underscore. Returns zero for null or garbage string.
  # 
  # NOTE: '0.3'.to_r isn't the same as 0.3.to_r. The former is equivalent to
  # '3/10'.to_r, but the latter isn't so.
  # 
  # For example:
  # 
  #   '  2  '.to_r       #=> (2/1)
  #   '300/2'.to_r       #=> (150/1)
  #   '-9.2'.to_r        #=> (-46/5)
  #   '-9.2e2'.to_r      #=> (-920/1)
  #   '1_234_567'.to_r   #=> (1234567/1)
  #   '21 june 09'.to_r  #=> (21/1)
  #   '21/06/09'.to_r    #=> (7/2)
  #   'bwv 1079'.to_r    #=> (0/1)
  #              
  def to_r
    str = StringScanner.new(self)
    str.skip(/ */)
    error = lambda do |return_value|
      str.terminate()
      return return_value
    end
    int = lambda do |maybe_empty|
      result1 = str.scan(/[0-9_]*/)
      return error[0] if result1.empty? and not maybe_empty
      return error[0] if result1[0] == ?_ or result1[-1] == ?_
      return result1.to_i
    end
    sign = lambda do
      (str.scan(/[\-\+]?/) == '-') ? (-1) : (+1)
    end
    float = lambda do
      integer_part = sign[] * int[true]
      fractional_part = 0
      if str.scan(/\./) then
        fractional_part = int[false]
      end
      mantissa = Rational(
        (integer_part.to_s + fractional_part.to_s).to_i,
        ("1" + "0" * fractional_part.to_s.length).to_i
      )
      exponent = 0
      if str.scan(/[eE]/) then
        exponent = sign[] * int[false]
      end
      return mantissa * 10.to_r ** exponent
    end
    result = float[]
    if str.scan(/\//) then
      result /= float[]
    end
    return result
  end
  
end

  
end
