#!/usr/bin/env ruby

class Addr2Sym
  def initialize mapfile
    @maps = Hash.new

    mapfile.each_line do |line|
      range, perm, offset, dev, inode, pathname = line.split
      if perm.include? 'x'
        first, last = range.split '-'
        @maps[Range.new(first.hex, last.hex)] = pathname
      end
    end
  end

  # translate address(es) to
  # (an array of) <funcname, offset, filename_where_func_is_defined>.
  def translate addr
    if addr.respond_to?(:map)
      addr.map { |e| translate_one e }
    else
      translate_one addr
    end
  end

  #
  # private methods
  #
  private

  def symbol_table_of pathname
    entry = Struct.new :address, :size, :name

    readelf_s = `readelf -s #{pathname}`
    readelf_s.each_line.inject([]) do |tbl, line|
      idx, address, size, type, bind, vis, ndx, name = line.split
      if size.to_i > 0 and type == 'FUNC'
        tbl.push entry.new(address.hex, size.to_i, name)
      else
        tbl
      end
    end
  end

  def executable? pathname
    elfheader = `readelf -h #{pathname}`
    /Type:\s+EXEC/ =~ elfheader
  end

  def translate_one addr
    @maps.each do |range, pathname|
      if range.include? addr
        symtbl = symbol_table_of pathname

        if executable? pathname
          offset = addr
        else
          offset = addr - range.first
        end

        ret_type = Struct.new :funcname, :offset, :pathname
        s = ret_type.new('?', nil, pathname)
        symtbl.each do |entry|
          if entry.address < offset and entry.address + entry.size > offset
            s.funcname = entry.name
            s.offset = offset - entry.address
            break
          end
        end

        return s
      end
    end
  end
end
