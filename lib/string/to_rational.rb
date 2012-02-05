require 'mathn'


class String
  
  # 
  # converts this String to Rational or returns 0 (or nil) if the String can not
  # be converted.
  # 
  def to_rational(return_nil_on_error = false)
    #
    error_value =
      if return_nil_on_error then nil
      else 0; end
    #
    mantissa, exponent = self.split(/[Ee]/, 2)
    exponent ||= "0"
    # Parse mantissa.
    return error_value unless /^[\-\+]?[0-9]*(\.[0-9]*)?$/ === mantissa
    integer_part, fractional_part = mantissa.split(".", 2)
    fractional_part ||= ""
    mantissa = Rational(
      (integer_part + fractional_part).to_i,
      ("1" + "0" * fractional_part.length).to_i
    )
    # Parse exponent.
    return error_value unless /^[\-\+]?[0-9]+$/ === exponent
    exponent = exponent.to_i
    #
    return mantissa * Rational(10, 1) ** exponent
  end
  
end
