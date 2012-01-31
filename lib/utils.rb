

# raises error telling that method called this function is abstract.
def abstract
  raise "#{caller[0][/`.*?'$/]} is abstract"
end


# executes given block once.
# 
# The block is executed inside a loop, i. e. all constructs available in
# the loop are available in the block.
# 
# Example:
# 
#   once { print "10,"; redo }  #=> 10,10,10,10,10,10,10,...
# 
def once
  while true; yield; break; end
end
