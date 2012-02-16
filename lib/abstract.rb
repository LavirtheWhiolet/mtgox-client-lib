
# raises error telling that method called this function is abstract.
def abstract
  raise "#{caller[0][/`.*?'$/]} is abstract"
end
