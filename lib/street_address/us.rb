module StreetAddress
  class US

    require 'street_address/us/address'
    require 'street_address/us/directions'
    require 'street_address/us/states'
    require 'street_address/us/street_types'

    include Directions
    include States
    include StreetTypes

    UNIT_PREFIX_PATTERN = /^(su?i?te|p\W*[om]\W*b(?:ox)?|dept|apt|apartment|ro*m|fl|unit|box|lot)\.?$/i
    UNIT_PATTERN        = /^([a-z]([-\/]?\d+)|\d+[-\/]?(\d+|[a-z])?)$/i
    CORNER_PATTERN      = /^(&|and|at)$/i
    LINE_PATTERN        = /,|[\r\n]{1-2}/

    def self.parse(location, options = {})
      parser = self.new(options)
      parser.parse(location)
    end

    def initialize(options = {})
      @options = options
    end

    def parse(location)
      reset location
      parse_number
      if @address.number.nil? and intersection?
        parse_intersection
      else
        parse_address
      end
      if @address.valid?(@options)
        @options[:normalize] == false ? @address : normalize_address(@address)
      end
    end

  private

    def reset(location)
      @location = location
      @address  = Address.new({})
      @tokens   = tokenize location
    end

    def parse_address
      street, other = split_parts
      parse_direction_prefix  street
      parse_direction_suffix  street
      parse_zip               other if other.any?
      parse_leading_unit      other if other.any?
      parse_state             other if other.any?
      parse_trailing_unit     street unless @address.unit
      parse_street            street
      parse_city              other
    end

    def parse_city(tokens)
      @address.city = tokens.join(" ") if tokens.any?
    end

    def parse_state(tokens)
      @address.state = tokens.pop if state?(tokens.last)
    end

    def parse_zip(tokens)
      if tokens.last =~ /(\d{5})-?(\d{4})?/
        @address.postal_code     = $1
        @address.postal_code_ext = $2
        tokens.pop
      end
    end

    def parse_leading_unit(tokens)
      @address.unit_prefix  = tokens.shift if unit_prefix?(tokens.first)
      @address.unit         = tokens.shift if unit?(tokens.first)
    end

    def parse_trailing_unit(tokens)
      @address.unit = tokens.pop if unit?(tokens.last)
      if @address.unit and unit_prefix?(tokens.last)
        @address.unit_prefix = tokens.pop
      end
    end

    def parse_street(tokens)
      @address.street = tokens.join(" ") unless tokens.empty?
    end

    def parse_number
      @address.number = @tokens.shift if @tokens.first =~ /\d+-?\d*[a-z]?/i
    end

    def parse_direction_prefix(tokens)
      if tokens.count > 1 and direction?(tokens.first)
        @address.prefix = tokens.shift
      end
    end

    def parse_direction_suffix(tokens)
      if tokens.count > 1 and direction?(tokens.last)
        @address.suffix = tokens.pop
      end
    end

    def parse_direction_prefix2(tokens)
      if tokens.count > 1 and direction?(tokens.first)
        @address.prefix2 = tokens.shift
      end
    end

    def parse_direction_suffix2(tokens)
      if tokens.count > 1 and direction?(tokens.last)
        @address.suffix2 = tokens.pop
      end
    end

    def tokenize(str)
      str.strip.split(/[ ,#\n\r\t]+/)
    end

    def split_parts
      street, other = split_parts_by_street_type
      street, other = @location.split(LINE_PATTERN, 2).map{|l| tokenize l } if street.nil?
      other ||= []
      [street, other]
    end

    def split_parts_by_street_type
      street_type_index = nil
      @tokens.each_with_index do |t, i|
        if i > 0 and street_types[t.downcase]
          street_type_index = i
          @address.street_type = t
          next_token = @tokens[i+1]
          break unless next_token and street_types[next_token.downcase]
        end
      end
      if street_type_index
        street = @tokens[0..(street_type_index - 1)]
        other  = @tokens[(street_type_index + 1)..-1]
        @address.suffix = other.shift if other.any? and direction?(other.first)
        [street, other]
      else
        nil
      end
    end

    def intersection?
      @tokens[1..-2].grep(CORNER_PATTERN).any?
    end

    def state?(val)
      states.key?(val.downcase) or states.value?(val.upcase)
    end

    def direction?(val)
      directions.key?(val.downcase) or directions.value?(val)
    end

    def unit?(val)
      !!(val =~ UNIT_PATTERN)
    end

    def unit_prefix?(val)
      !!(val =~ UNIT_PREFIX_PATTERN)
    end

    def states
      STATE_CODES
    end

    def street_types
      STREET_TYPES_LIST
    end

    def directions
      DIRECTIONS
    end

    # TODO: ugly method. refector.
    def parse_intersection
      lines = @location.split(LINE_PATTERN, 2)
      if lines.length == 2
        other = tokenize lines.last
        streets = tokenize lines.first
      else
        other = @tokens
        streets = nil
      end
      parse_zip   other
      parse_state other
      if streets
        @address.city = other.join(" ")
      else
        city = []
        until other.empty? or street_types.key?(other.last.downcase)
          city << other.pop
        end
        if other.count > 2
          @address.city = city.join(" ")
          streets = other
        end
      end
      if streets
        intersection_index = streets[1..-2].index do |t|
          t =~ CORNER_PATTERN
        end
        if intersection_index
          street1 = streets[0..intersection_index]
          parse_direction_prefix street1
          parse_direction_suffix street1
          @address.street_type = street1.pop if street1.count > 1 and street_types.key?(street1.last.downcase)
          @address.street = street1.join(" ")
          street2 = streets[(intersection_index + 2)..-1]
          parse_direction_prefix2 street2
          parse_direction_suffix2 street2
          @address.street_type2 = street2.pop if street2.count > 1 and street_types.key?(street2.last.downcase)
          @address.street2 = street2.join(" ")
        end
      end
    end
      
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
        STATE_CODES[state.downcase]
      end
    end
    
    def normalize_street_type(s_type)
      s_type.downcase!
      s_type = STREET_TYPES[s_type] || s_type if STREET_TYPES_LIST[s_type]
      s_type.capitalize
    end
    
    def normalize_directional(dir)
      if dir.length < 3
        dir.upcase
      else
        DIRECTIONS[dir.downcase]
      end
    end

  end
end
