
# executes given block once. Returns what the block returns.
# 
# The block is executed inside a loop, i. e. all constructs available in
# the loop are available in the block.
# 
# Example:
# 
#   once { print "10,"; redo }  #=> 10,10,10,10,10,10,10,...
# 
def once
  while true; break yield; end
end
