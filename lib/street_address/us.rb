module StreetAddress
  class US

    require 'street_address/us/address'
    require 'street_address/us/directions'
    require 'street_address/us/states'
    require 'street_address/us/street_types'

    include Directions
    include States
    include StreetTypes
    
    class << self
      attr_accessor(
        :street_type_regexp,
        :number_regexp,
        :fraction_regexp,
        :state_regexp,
        :city_and_state_regexp,
        :direct_regexp, 
        :zip_regexp,
        :corner_regexp,
        :unit_regexp,
        :street_regexp,
        :place_regexp,
        :address_regexp,
        :informal_address_regexp
      )
    end
      
    self.street_type_regexp = STREET_TYPES_LIST.keys.join("|")
    self.number_regexp = '\d+-?\d*'
    self.fraction_regexp = '\d+\/\d+'
    self.state_regexp = STATE_CODES.to_a.join("|").gsub(/ /, "\\s")
    self.city_and_state_regexp = '
      (?:
        ([^\d,]+?)\W+
        (' + state_regexp + ')
      )'
      
    self.direct_regexp = DIRECTIONS.keys.join("|") + 
      "|" + 
      DIRECTIONS.values.sort{ |a,b| 
        b.length <=> a.length 
      }.map{ |x| 
        f = x.gsub(/(\w)/, '\1.')
        [Regexp::quote(f), Regexp::quote(x)] 
      }.join("|")
    self.zip_regexp = '(\d{5})(?:-?(\d{4})?)'
    self.corner_regexp = '(?:\band\b|\bat\b|&|\@)'
    self.unit_regexp = '(?:(su?i?te|p\W*[om]\W*b(?:ox)?|dept|apt|apartment|ro*m|fl|unit|box)\W+|\#\W*)([\w-]+)'
    self.street_regexp = 
      '(?:
          (?:(' + direct_regexp + ')\W+
          (' + street_type_regexp + ')\b)
          |
          (?:(' + direct_regexp + ')\W+)?
          (?:
            ([^,]+)
            (?:[^\w,]+(' + street_type_regexp + ')\b)
            (?:[^\w,]+(' + direct_regexp + ')\b)?
           |
            ([^,]*\d)
            (' + direct_regexp + ')\b
           |
            ([^,]+?)
            (?:[^\w,]+(' + street_type_regexp + ')\b)?
            (?:[^\w,]+(' + direct_regexp + ')\b)?
          )
        )'
    self.place_regexp = 
      '(?:' + city_and_state_regexp + '\W*)?
       (?:' + zip_regexp + ')?'
    
    self.address_regexp =
      '\A\W*
        (' + number_regexp + ')\W*
        (?:' + fraction_regexp + '\W*)?' +
        street_regexp + '\W+
        (?:' + unit_regexp + '\W+)?' +
        place_regexp +
      '\W*\Z'
      
    self.informal_address_regexp =
      '\A\s*
        (' + number_regexp + ')\W*
        (?:' + fraction_regexp + '\W*)?' +
        street_regexp + '(?:\W+|\Z)
        (?:' + unit_regexp + '(?:\W+|\Z))?' +
        '(?:' + place_regexp + ')?'

=begin rdoc

    parses either an address or intersection and returns an instance of
    StreetAddress::US::Address or nil if the location cannot be parsed

    pass the arguement, :informal => true, to make parsing more lenient
    
====example
    StreetAddress::US.parse('1600 Pennsylvania Ave Washington, DC 20006')
    or:
    StreetAddress::US.parse('Hollywood & Vine, Los Angeles, CA')
    or
    StreetAddress::US.parse("1600 Pennsylvania Ave", :informal => true)
    
=end
    class << self
      #def parse(location, args = {})
      #  if Regexp.new(corner_regexp, Regexp::IGNORECASE).match(location)
      #    parse_intersection(location)
      #  elsif args[:informal]
      #    parse_address(location) || parse_informal_address(location)
      #  else 
      #    parse_address(location);
      #  end
      #end

      def parse(location, options = {})
        tokens = tokenize location
        return if tokens.empty?
        a = Address.new({})

        a.number = tokens.shift
        return unless a.number =~ /\d+-?\d*[a-z]?/i and tokens.any?

        street_type_index = nil
        tokens.each_with_index do |t, i|
          if i > 0 and street_types[t.downcase]
            street_type_index = i
            a.street_type = t
            next_token = tokens[i+1]
            break unless next_token and street_types[next_token.downcase]
          end
        end

        if street_type_index
          street_parts = tokens[0..(street_type_index - 1)]
          other_parts  = tokens[(street_type_index + 1)..-1]
          a.suffix = other_parts.shift if other_parts.any? and direction?(other_parts.first)
        else
          street_parts, other_parts = location.split(",", 2).map{|l| tokenize l }
          other_parts ||= []
        end

        if street_parts.count > 1 and direction?(street_parts.first)
          a.prefix = street_parts.shift
        end

        if street_parts.count > 1 and direction?(street_parts.last)
          a.prefix = street_parts.pop
        end

        a.street = street_parts.join(" ")

        parse_zip   a, other_parts if other_parts.any?
        parse_unit  a, other_parts if other_parts.any?
        parse_state a, other_parts if other_parts.any?
        a.city = other_parts.join(" ") if other_parts.any?

        normalize_address a
      end

      def tokenize(str)
        str.strip.split(/[^[:alnum:]-]+/)
      end

      def parse_state(address, tokens)
        state = tokens.last
        if state?(state)
          address.state = state
          tokens.pop
        end
      end

      def parse_zip(address, tokens)
        zip = tokens.last
        if zip =~ /(\d{5})-?(\d{4})?/
          address.postal_code     = $1
          address.postal_code_ext = $2
          tokens.pop
        end
      end

      UNIT_PREFIX_PATTERN = /^(su?i?te|p\W*[om]\W*b(?:ox)?|dept|apt|apartment|ro*m|fl|unit|box|lot)\.?$/i
      UNIT_PATTERN = /^([a-z]([-\/]?\d+)|\d+[-\/]?(\d+|[a-z])?)$/i
      def parse_unit(address, tokens)
        prefix = tokens.first
        if prefix =~ UNIT_PREFIX_PATTERN
          address.unit_prefix = prefix
          tokens.shift
        end

        tokens.shift if tokens.first == "#"

        unit = tokens.first
        if unit =~ UNIT_PATTERN
          address.unit = unit
          tokens.shift
        end
      end

      def state?(val)
        states.key?(val.downcase) or states.value?(val.upcase)
      end

      def direction?(val)
        directions.key?(val.downcase) or directions.value?(val)
      end

      def states
        self::STATE_CODES
      end

      def street_types
        self::STREET_TYPES_LIST
      end

      def directions
        self::DIRECTIONS
      end
=begin rdoc
    
    parses only an intersection and returnsan instance of
    StreetAddress::US::Address or nil if the intersection cannot be parsed
    
====example
    address = StreetAddress::US.parse('Hollywood & Vine, Los Angeles, CA')
    assert address.intersection?
    
=end
      def parse_intersection(inter)
        regex = Regexp.new(
          '\A\W*' + street_regexp + '\W*?
          \s+' + corner_regexp + '\s+' +
          street_regexp + '\W+' +
          place_regexp + '\W*\Z', Regexp::IGNORECASE + Regexp::EXTENDED
        )
        
        return unless match = regex.match(inter)
        
        normalize_address(
          StreetAddress::US::Address.new(
            :street => match[4] || match[9],
            :street_type => match[5],
            :suffix => match[6],
            :prefix => match[3],
            :street2 => match[15] || match[20],
            :street_type2 => match[16],
            :suffix2 => match[17],
            :prefix2 => match[14],
            :city => match[23],
            :state => match[24],
            :postal_code => match[25]
          )
        )
      end
      
=begin rdoc

    parses only an address and returnsan instance of
    StreetAddress::US::Address or nil if the address cannot be parsed

====example
    address = StreetAddress::US.parse('1600 Pennsylvania Ave Washington, DC 20006')
    assert !address.intersection?

=end
      def parse_address(addr)
         regex = Regexp.new(address_regexp, Regexp::IGNORECASE + Regexp::EXTENDED)

         return unless match = regex.match(addr)

         normalize_address(
           StreetAddress::US::Address.new(
           :number => match[1],
           :street => match[5] || match[10] || match[2],
           :street_type => match[6] || match[3],
           :unit => match[14],
           :unit_prefix => match[13],
           :suffix => match[7] || match[12],
           :prefix => match[4],
           :city => match[15],
           :state => match[16],
           :postal_code => match[17],
           :postal_code_ext => match[18]
           )
        )
      end

      def parse_informal_address(addr)
         regex = Regexp.new(informal_address_regexp, Regexp::IGNORECASE + Regexp::EXTENDED)

         return unless match = regex.match(addr)

         normalize_address(
           StreetAddress::US::Address.new(
           :number => match[1],
           :street => match[5] || match[10] || match[2],
           :street_type => match[6] || match[3],
           :unit => match[14],
           :unit_prefix => match[13],
           :suffix => match[7] || match[12],
           :prefix => match[4],
           :city => match[15],
           :state => match[16],
           :postal_code => match[17],
           :postal_code_ext => match[18]
           )
        )
      end
      
      private
      def normalize_address(addr)
        addr.state = normalize_state(addr.state) unless addr.state.nil?
        addr.street_type = normalize_street_type(addr.street_type) unless addr.street_type.nil?
        addr.prefix = normalize_directional(addr.prefix) unless addr.prefix.nil?
        addr.suffix = normalize_directional(addr.suffix) unless addr.suffix.nil?
        addr.street.gsub!(/\b([a-z])/) {|wd| wd.capitalize} unless addr.street.nil?
        addr.street_type2 = normalize_street_type(addr.street_type2) unless addr.street_type2.nil?
        addr.prefix2 = normalize_directional(addr.prefix2) unless addr.prefix2.nil?
        addr.suffix2 = normalize_directional(addr.suffix2) unless addr.suffix2.nil?
        addr.street2.gsub!(/\b([a-z])/) {|wd| wd.capitalize} unless addr.street2.nil?
        addr.city.gsub!(/\b([a-z])/) {|wd| wd.capitalize} unless addr.city.nil?
        addr.unit_prefix.capitalize! unless addr.unit_prefix.nil?
        return addr
      end
      
      def normalize_state(state)
        if state.length < 3
          state.upcase
        else
          self::STATE_CODES[state.downcase]
        end
      end
      
      def normalize_street_type(s_type)
        s_type.downcase!
        s_type = self::STREET_TYPES[s_type] || s_type if self::STREET_TYPES_LIST[s_type]
        s_type.capitalize
      end
      
      def normalize_directional(dir)
        if dir.length < 3
          dir.upcase
        else
          self::DIRECTIONS[dir.downcase]
        end
      end
    end

  end
end
