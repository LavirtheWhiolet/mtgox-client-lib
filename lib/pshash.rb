

# Persistent, synchronized between processes Hash.
class PSHash < Hash
  
  private_class_method :new
  
  class << self
  
    # opens PSHash stored in specified file and passes it to +block+.
    # If the file does not exist then new PSHash is created.
    # 
    # No other process may access the PSHash until this operation terminates.
    # 
    def open(filename, &block)
      # Grab lock.
      File.open(lockfilename(filename), "w") do |lockfile|
        lockfile.flock(File::LOCK_EX)
        # Read actual hash (or create new one).
        hash =
          if File.exist? filename then File.open(filename, "rb") { |file| Marshal.load(file) }
          else Hash.new; end
        begin
          #
          return yield(hash)
        ensure
          # Save the hash (anyway).
          File.open(filename, "wb") { |file| Marshal.dump(hash, file) }
        end
      end  
    end
    
    # deletes PSHash stored in specified file.
    def delete(filename)
      # Grab lock.
      File.open(lockfilename(filename), "w") do |lockfile|
        lockfile.flock(File::LOCK_EX)
        # Delete everything!
        File.delete filename if File.exist? filename
        File.delete lockfilename(filename)
      end
    end
    
    private
    
    def lockfilename(filename)
      "~#{filename}.lock"
    end
    
  end
  
end
