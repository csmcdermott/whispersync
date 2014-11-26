#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'optparse'

options = {}
optparse = OptionParser.new do|opts|
  opts.banner = 'asdf'
  opts.on('-s', '--source SOURCE', 'Source (file or directory).') do |source|
    options[:source] = source
  end 
  opts.on('-d', '--destination DEST', 'Destination (file or directory).') do |dest|
    options[:dest] = dest
  end
  opts.on('-H', '--host HOST', 'Destination host.') do |host|
    options[:host] = host
  end
  options[:verbose] = false
  opts.on('-v', '--verbose', 'Verbose output.') do
    options[:verbose] = true
  end
  options[:noop] = false
  opts.on('-n', '--noop', 'Fake it, just print what *would* happen if it were for real.') do
    options[:verbose] = true
  end
  opts.on('-h', '--help', 'Display this help menu') do
    puts opts
    exit
  end
end
optparse.parse!

if options[:verbose]
  puts "Arguments and options:"
  options.each do |k,v|
    puts "  - #{k}: #{v}"
  end
end

unless options.has_key?(:source) && options.has_key?(:dest)
  puts "Source and destination arguments are required."
  exit 2
end

unless File.exists?(options[:source])
  puts "Source does not exist."
  exit 2
end

source_path = ''
dest_host = ''
dest_path = ''
dest_file = ''

if /\.wsp/ =~ options[:dest]
  dest_path = File.dirname(options[:dest])
  dest_file = File.basename(options[:dest])
else
  dest_path = options[:dest]
end

if options[:verbose]
  puts "dest_path: #{dest_path}"
  puts "dest_file: #{dest_file}"
end

if options[:host]
  dest_host = options[:host]
end

differences = 0
errors = 0
source_files = []

if File.file?(options[:source])
  source_path = File.dirname(options[:source])
  source_files << File.basename(options[:source])
else # If it's not a file, it must be a directory
  source_path = options[:source]
  Dir.chdir(options[:source])
  Dir.glob('**/*.wsp') do |file|
    source_files << file
  end
end

if options[:verbose]
  puts "source_path: #{source_path}"
end

if options[:verbose]
  puts "List of source files to examine:"
  source_files.each do |file|
    puts "  - #{source_path}/#{file}"
  end
end

source_files.each do |file|
  if options[:verbose]
    puts "Starting in on #{file}..."
  end
  source_cmd = "/usr/local/bin/whisper-dump.py #{source_path}/#{file}"
  source_output = `#{source_cmd}`.split("\n")
  dest_command = '/usr/local/bin/whisper-dump.py '
  if dest_file == ''
    dest_arg = "#{dest_path}/#{file}"
  else
    dest_arg = "#{dest_path}/#{dest_file}"
  end
  dest_command = dest_command + dest_arg
  unless dest_host == ''
    dest_command = "ssh #{options[:host]} \"#{dest_command}\" 2> /dev/null"
  end
  if options[:verbose]
    puts "  - source_cmd: #{source_cmd}"
    puts "  - dest_command: #{dest_command}"
  end
  dest_output = `#{dest_command}`.split("\n")
  if source_output == dest_output
    puts "  - no differences, proceeding to next file"
    next
  else
    changes = {}
    for c in 0..(source_output.length-1)
      unless source_output[c] == dest_output[c]
        #puts "###############"
        #puts source_output[c]
        #puts dest_output[c]
        #puts "###############"
        if /(\d+): (\d+),\s+(\S+)/ =~ source_output[c]
          changes[$2] = $3
        end
      end
    end
    if options[:verbose]
      puts "  - #{changes.length} differences found."
    end
    unless options[:noop]
      change_string = ''
      changes.each do |timestamp,value|
        change_string = change_string + "#{timestamp}:#{value} "
        if options[:verbose]
          puts "#{timestamp}:#{value}"
        end
      end
      #puts "whisper-update.py #{dest_arg} #{change_string}"
    end
  end
end
