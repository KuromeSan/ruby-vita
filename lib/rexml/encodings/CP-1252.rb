#
# This class was contributed by Mikko Tiihonen mikko DOT tiihonen AT hut DOT fi
#
module REXML
  module Encoding
  	register( "CP-1252" ) do |o|
  		class << o
  			alias encode encode_cp1252
			alias decode decode_cp1252
  		end
  	end

    # Convert from UTF-8
    def encode_cp1252(content)
      array_utf8 = content.unpack('U*')
      array_enc = []
      array_utf8.each do |num|
        case num
          # shortcut first bunch basic characters
        when 0..0xFF; array_enc << num
          # characters added compared to iso-8859-1
        when 0x20AC; array_enc << 0x80 # 0xe2 0x82 0xac
        when 0x201A; array_enc << 0x82 # 0xe2 0x82 0x9a
        when 0x0192; array_enc << 0x83 # 0xc6 0x92
        when 0x201E; array_enc << 0x84 # 0xe2 0x82 0x9e
        when 0x2026; array_enc << 0x85 # 0xe2 0x80 0xa6
        when 0x2020; array_enc << 0x86 # 0xe2 0x80 0xa0
        when 0x2021; array_enc << 0x87 # 0xe2 0x80 0xa1
        when 0x02C6; array_enc << 0x88 # 0xcb 0x86
        when 0x2030; array_enc << 0x89 # 0xe2 0x80 0xb0
        when 0x0160; array_enc << 0x8A # 0xc5 0xa0
        when 0x2039; array_enc << 0x8B # 0xe2 0x80 0xb9
        when 0x0152; array_enc << 0x8C # 0xc5 0x92
        when 0x017D; array_enc << 0x8E # 0xc5 0xbd
        when 0x2018; array_enc << 0x91 # 0xe2 0x80 0x98
        when 0x2019; array_enc << 0x92 # 0xe2 0x80 0x99
        when 0x201C; array_enc << 0x93 # 0xe2 0x80 0x9c
        when 0x201D; array_enc << 0x94 # 0xe2 0x80 0x9d
        when 0x2022; array_enc << 0x95 # 0xe2 0x80 0xa2
        when 0x2013; array_enc << 0x96 # 0xe2 0x80 0x93
        when 0x2014; array_enc << 0x97 # 0xe2 0x80 0x94
        when 0x02DC; array_enc << 0x98 # 0xcb 0x9c
        when 0x2122; array_enc << 0x99 # 0xe2 0x84 0xa2
        when 0x0161; array_enc << 0x9A # 0xc5 0xa1
        when 0x203A; array_enc << 0x9B # 0xe2 0x80 0xba
        when 0x0152; array_enc << 0x9C # 0xc5 0x93
        when 0x017E; array_enc << 0x9E # 0xc5 0xbe
        when 0x0178; array_enc << 0x9F # 0xc5 0xb8
        else
          # all remaining basic characters can be used directly
          if num <= 0xFF
            array_enc << num
          else
            # Numeric entity (&#nnnn;); shard by  Stefan Scholl
            array_enc.concat "&\##{num};".unpack('C*')
          end
        end
      end
      array_enc.pack('C*')
    end

    # Convert to UTF-8
    def decode_cp1252(str)
      array_latin9 = str.unpack('C*')
      array_enc = []
      array_latin9.each do |num|
        case num
          # characters that added compared to iso-8859-1
        when 0x80; array_enc << 0x20AC # 0xe2 0x82 0xac
        when 0x82; array_enc << 0x201A # 0xe2 0x82 0x9a
        when 0x83; array_enc << 0x0192 # 0xc6 0x92
        when 0x84; array_enc << 0x201E # 0xe2 0x82 0x9e
        when 0x85; array_enc << 0x2026 # 0xe2 0x80 0xa6
        when 0x86; array_enc << 0x2020 # 0xe2 0x80 0xa0
        when 0x87; array_enc << 0x2021 # 0xe2 0x80 0xa1
        when 0x88; array_enc << 0x02C6 # 0xcb 0x86
        when 0x89; array_enc << 0x2030 # 0xe2 0x80 0xb0
        when 0x8A; array_enc << 0x0160 # 0xc5 0xa0
        when 0x8B; array_enc << 0x2039 # 0xe2 0x80 0xb9
        when 0x8C; array_enc << 0x0152 # 0xc5 0x92
        when 0x8E; array_enc << 0x017D # 0xc5 0xbd
        when 0x91; array_enc << 0x2018 # 0xe2 0x80 0x98
        when 0x92; array_enc << 0x2019 # 0xe2 0x80 0x99
        when 0x93; array_enc << 0x201C # 0xe2 0x80 0x9c
        when 0x94; array_enc << 0x201D # 0xe2 0x80 0x9d
        when 0x95; array_enc << 0x2022 # 0xe2 0x80 0xa2
        when 0x96; array_enc << 0x2013 # 0xe2 0x80 0x93
        when 0x97; array_enc << 0x2014 # 0xe2 0x80 0x94
        when 0x98; array_enc << 0x02DC # 0xcb 0x9c
        when 0x99; array_enc << 0x2122 # 0xe2 0x84 0xa2
        when 0x9A; array_enc << 0x0161 # 0xc5 0xa1
        when 0x9B; array_enc << 0x203A # 0xe2 0x80 0xba
        when 0x9C; array_enc << 0x0152 # 0xc5 0x93
        when 0x9E; array_enc << 0x017E # 0xc5 0xbe
        when 0x9F; array_enc << 0x0178 # 0xc5 0xb8
        else
          array_enc << num
        end
      end
      array_enc.pack('U*')
    end
  end
end
