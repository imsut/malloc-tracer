#!/usr/bin/env ruby

require 'optparse'
require 'pp'

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
maps = nil
unless mapfile.nil?
  maps = Hash.new
  File.open(mapfile) do |file|
    file.each_line do |line|
      range, perm, offset, dev, inode, pathname = line.split
      if perm.include? 'x'
        first, last = range.split '-'
        maps[Range.new(first.hex, last.hex)] = pathname
      end
    end
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

def symbol_table_of pathname
  symtbl_entry = Struct.new :address, :size, :name

  tbl = Array.new

  readelf_s = `readelf -s #{pathname}`
  readelf_s.each_line do |line|
    idx, address, size, type, bind, vis, ndx, name = line.split
    if size.to_i > 0 and type == 'FUNC'
      tbl.push symtbl_entry.new(address.hex, size.to_i, name)
    end
  end

  tbl
end

def executable? pathname
  elfheader = `readelf -h #{pathname}`
  /Type:\s+EXEC/ =~ elfheader
end

def addr2sym maps, addr
  maps.each do |range, pathname|
    if range.include? addr
      symtbl = symbol_table_of pathname

      if executable? pathname
        offset = addr
      else
        offset = addr - range.first
      end

      funcname = '?'
      offset2 = '?'
      symtbl.each do |entry|
        if entry.address < offset and entry.address + entry.size > offset
          funcname = entry.name
          offset2 = (offset - entry.address).to_s(16)
        end
      end

      return "#{funcname}+0x#{offset2} in #{pathname}"
    end
  end
end

arr.each_index do |idx|
  puts "#{idx}-th memory leak:"

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
      sym = addr2sym maps, caller.hex
      puts "    #{caller} #{sym}"
    end
  end

  puts
end
