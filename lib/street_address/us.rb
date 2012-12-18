module StreetAddress
  class US

    require 'street_address/us/address'
    require 'street_address/us/directions'
    require 'street_address/us/states'
    require 'street_address/us/street_types'

    include Directions
    include States
    include StreetTypes

    VERSION             = '1.1.0'
    UNIT_PREFIX_PATTERN = /^(su?i?te|p\W*[om]\W*b(?:ox)?|dept|apt|apartment|ro*m|fl|unit|box|lot|#)\.?$/i
    UNIT_PATTERN        = /^#?([a-z][-\/]?\d*|\d+[-\/]?(\d+|[a-z])?)$/i
    CORNER_PATTERN      = /^(&|and|at)$/i
    LINE_PATTERN        = /,|[\r\n]{1,2}/
    TOKEN_PATTERN       = /^[A-Za-z0-9'\-&#\.\/]+$/
    SEPARATOR           = -1

=begin rdoc

    parses either an address or intersection and returns an instance of
    StreetAddress::US::Address or nil if the location cannot be parsed

    pass the argument, :informal => true, to make parsing more lenient
    
====example
    StreetAddress::US.parse('1600 Pennsylvania Ave Washington, DC 20006')
    or:
    StreetAddress::US.parse('Hollywood & Vine, Los Angeles, CA')
    or
    StreetAddress::US.parse("1600 Pennsylvania Ave", :informal => true)
    or
    StreetAddress::US.parse("1600 Pennsylvania Ave", :street_only => true)
    
=end
    def self.parse(location, options = {})
      parser = self.new(options)
      parser.parse(location)
    end

    def initialize(options = {})
      @options = options
    end

    def parse(location, options = nil)
      reset location
      return nil unless @tokens.all?{|t| t =~ TOKEN_PATTERN or t == SEPARATOR }
      options = options ? @options.merge(options) : @options
      parse_number
      if @address.number.nil? and intersection?
        parse_intersection
      elsif @address.number and @tokens.any?
        parse_address
      else
        return nil
      end
      if @address.valid?(options)
        @options[:normalize] == false ? @address : normalize_address(@address)
      end
    rescue
      nil
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
      parse_trailing_unit     street unless @address.unit or street.one?
      parse_street            street
      other = street if other.empty? and !street.empty?
      parse_state             other if other.any?
      parse_city              other
    end

    def parse_city(tokens)
      @address.city = tokens.join(" ") if tokens.any?
    end

    def parse_state(tokens)
      @address.state = tokens.pop if state?(tokens.last)
      tokens.pop if tokens.last == SEPARATOR
    end

    def parse_zip(tokens)
      if tokens.last =~ /(\d{5})-?(\d{4})?/
        @address.postal_code     = $1
        @address.postal_code_ext = $2
        tokens.pop
        tokens.pop if tokens.last == SEPARATOR
      end
    end

    def parse_leading_unit(tokens)
      @address.unit_prefix  = tokens.shift if unit_prefix?(tokens.first)
      @address.unit         = tokens.shift if unit?(tokens.first)
      tokens.shift if tokens.first == SEPARATOR
    end

    def parse_trailing_unit(tokens)
      if unit_prefix?(tokens[-2]) and unit?(tokens.last)
        @address.unit         = tokens.pop.match(UNIT_PATTERN)[1]
        @address.unit_prefix  = tokens.pop
      elsif tokens.last[0] == "#"
        @address.unit = tokens.pop.match(UNIT_PATTERN)[1]
      end
      tokens.pop if tokens.last == SEPARATOR
    end

    def parse_street(tokens)
      street = nil
      if tokens.count > 1
        (1..(tokens.count - 1)).to_a.reverse.each do |i|
          if street_type?(tokens[i])
            street = tokens.slice!(0, i)
            @address.street_type = tokens.shift.gsub(".", "")
            break
          end
        end
      end
      unless street
        street = tokens.clone
        tokens.clear
      end
      @address.street = street.join(" ") unless street.empty?
    end

    def parse_number
      if @tokens.first =~ /\d+-?\d*[a-z]?/i
        number = @tokens.shift 
        number << " #{@tokens.shift}" if @tokens.first =~ %r{^1/2$}
        @address.number = number
      end
    end

    def parse_direction_prefix(tokens)
      if tokens.count > 1 and direction?(tokens.first) and
          (
            tokens.count > 2 or !street_type?(tokens.last)
          )
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
      tokens = []
      pieces = str.strip.split(/ +/)
      pieces.each_with_index do |piece, i|
        if i < 1
          tokens << piece
        else
          tokens += separate_piece(piece)
        end
      end
      tokens
    end

    def separate_piece(piece)
      if piece =~ /\A(.+?)(\r?\n|,)\z/m
        separate_piece($1) + [SEPARATOR]
      else
        [].tap do |pieces|
          piece.split(/(?:\r?\n)+/).each_with_index do |t, i|
            pieces << SEPARATOR if i > 0
            pieces << t
          end
        end
      end
    end

    def split_parts
      street, other = [], []
      first_line = true
      @tokens.each do |t|
        first_line = false if t == SEPARATOR
        first_line ? street << t : other << t
      end
      other.shift if other.first == SEPARATOR
      [street, other]
    end

    def intersection?
      possible_corners = @tokens[1..-2]
      possible_corners and possible_corners.grep(CORNER_PATTERN).any?
    end

    def state?(val)
      states.key?(val.downcase) or states.value?(val.upcase)
    end

    def direction?(val)
      val = val.gsub(".","")
      directions.key?(val.downcase) or directions.value?(val.upcase)
    end

    def unit?(val)
      !!(val =~ UNIT_PATTERN)
    end

    def unit_prefix?(val)
      !!(val =~ UNIT_PREFIX_PATTERN)
    end

    def street_type?(val)
      !!street_types[val.downcase.gsub(".", "")]
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
