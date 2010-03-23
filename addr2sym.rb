#!/usr/bin/env ruby

class Addr2Sym
  def initialize mapfile
    @maps = Hash.new
    @symtbls = Hash.new

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

  def base_address_of_symtbl_of pathname
    # detect base address
    readelf_l = `readelf -Wl #{pathname}`

    base = 0
    readelf_l.each_line do |line|
      type, offset, virtaddr, physaddr, filesiz, memsize, rest = line.chomp.split(nil, 7)
      next unless type == 'LOAD' # ignore all except 'LOAD' sections

      flg, _, align = rest.rpartition(' ')
      next unless flg.include? 'E' # ignore non-'E'xecutable sections

      base = virtaddr.hex - (virtaddr.hex % align.hex)
    end

    base
  end

  def symbol_table_of pathname
    if @symtbls.key? pathname
      return @symtbls[pathname]
    end

    base = base_address_of_symtbl_of pathname

    entry = Struct.new :address, :name

    symlist = `objdump -d -j .text #{pathname} | grep -E "^[0-9a-f]+\s+.+:$"`
    symlist.each_line.inject([]) do |tbl, line|
      address, name_with_bracket = line.chomp.split
      md = /\<(.+)\>/.match(name_with_bracket)
      name = md[1]

      tbl.push entry.new(address.hex - base, name)
    end
  end

  def translate_one addr
    @maps.each do |range, pathname|
      if range.include? addr
        offset = addr - range.first

        ret_type = Struct.new :funcname, :offset, :pathname
        s = ret_type.new('?', nil, pathname)
        
        symtbl = symbol_table_of pathname
        symtbl.each_index do |idx|
          entry = symtbl[idx]
          if entry.address < offset and
              (symtbl[idx + 1].nil? or symtbl[idx + 1].address > offset)
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
