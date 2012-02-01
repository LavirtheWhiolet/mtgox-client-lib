

class ReentrantMutex
  
  def initialize()
    @mutex = Mutex.new
    @locking_thread = nil
  end
  
  def synchronized
    
    unless @mutex.locked?
      @mutex.synchronize do
        @locking_thread = Thread.current
        begin
          yield
        ensure
          @locking_thread = nil
        end
      end
    
    else
      if Thread.current == @locking_thread
        yield
      else
        @mutex.synchronize { yield }
      end
    end
    
  end
  
  alias synchronize synchronized
  
end
