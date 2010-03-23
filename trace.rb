#!/usr/bin/env ruby

require 'optparse'
require 'pp'
require 'addr2sym'

mapfile = nil
target = nil

opt = OptionParser.new
opt.on('-m mapfile') { |v| mapfile = v }
opt.on('-t target') { |v| target = v }
opt.parse!

unless mapfile.nil? ^ target.nil?
  puts("Either mapfile or target must be given.")
  exit
end

# read mapfile and construct address-to-binary map
# maps: Range -> String
a2s = nil
unless mapfile.nil?
  File.open(mapfile) do |file|
    a2s = Addr2Sym.new file
  end
end

filename = ARGV[0]
puts "reading '#{filename}' ..."

allocation = Struct.new(:address, :size, :callstack)

arr = []

File.open(filename) do |f|
  f.each_line do |line|
    line.chomp!

    type, address, size, *callstack = line.split(' ')
    if type == 'm' # malloc
      arr.push(allocation.new(address, size, callstack))
    elsif type == 'f' # free
      idx = arr.rindex { |alloc| alloc.address == address}
      if idx.nil?
        puts "orphaned free found, but continue processing..."
        next
      end
      
      arr.delete_at idx
    else # unknown
      puts "Unknown operation type found: #{type}."
    end
  end
end

if arr.empty?
  puts "no memory leaks found."
  exit
end

size = arr.size
puts "#{size} leaks found..."
puts

arr.each_index do |idx|
  puts "memory leak #{idx}:"

  alloc = arr[idx]
  puts "  address  : #{alloc.address}"
  puts "  size     : #{alloc.size.hex}"
  puts "  callstack:"

  alloc.callstack.each do |caller|
    if target
      output = `addr2line -Cife #{target} #{caller}`
      func, line = output.split
      puts "    #{caller} #{func} #{line}"
    else
      sym = a2s.translate caller.hex
      offset = sym.offset.nil? ? '?' : sym.offset.to_s(16)
      puts "    #{caller} #{sym.funcname}+0x#{offset} in #{sym.pathname}"
    end
  end

  puts
end
