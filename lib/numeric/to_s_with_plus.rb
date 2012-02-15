

class Numeric
  
  # The same as Numeric#to_s but adds "+" sign at beginning if this Numeric
  # is greater than 0.
  def to_s_with_plus(*args)
    (if self > 0 then "+" else "" end) + (self.to_s(*args))
  end
  
end
