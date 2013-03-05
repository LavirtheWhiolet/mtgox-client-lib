# Add this file's directory to the library path.
$: << File.dirname(__FILE__)
# Require gems.
require 'rubygems'
gem 'facets', '2.9.2'
require 'facets'

desc "Installs executables and library modules into home directory."
task :'install-home' do
  # Check whether requirements are met.
  require 'lib/requirements' rescue raise %Q{Requiements are not met; see "lib/requirements.rb"}
  # Install library modules.
  mkdir_p dest_lib_dir = "#{ENV["HOME"]}/lib/mtgox-client-lib"
  for entry in FileList["lib/*"]
    cp_r entry, dest_lib_dir
  end
  # Install executables.
  mkdir_p dest_dir = "#{ENV["HOME"]}/bin"
  for file in FileList["bin/*"]
    #
    if file.file.directory?
      STDERR.puts %Q{WARNING: "#{file}" is a directory. I don't know how to install directories of executables}
      next
    end
    #
    cp file, dest_file = "#{dest_dir}/#{file.file.basename.ext('')}"
    #
    chmod 0755, dest_file
    # Prepend she-bang.
    File.rewrite(dest_file) do |content|
<<CODE.chomp
#!/usr/bin/env ruby
$LOAD_PATH << '#{dest_lib_dir.gsub("\\", "\\\\").gsub("'", "\\'")}'
#{content}
CODE
    end
  end
end
