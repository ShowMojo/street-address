=begin rdoc

=== Usage:
    StreetAddress::US.parse("1600 Pennsylvania Ave, washington, dc")

=== Valid Address Formats

    1600 Pennsylvania Ave Washington DC 20006
    1600 Pennsylvania Ave #400, Washington, DC, 20006
    1600 Pennsylvania Ave Washington, DC
    1600 Pennsylvania Ave #400 Washington DC
    1600 Pennsylvania Ave, 20006
    1600 Pennsylvania Ave #400, 20006
    1600 Pennsylvania Ave 20006
    1600 Pennsylvania Ave #400 20006

=== Valid Intersection Formats

    Hollywood & Vine, Los Angeles, CA
    Hollywood Blvd and Vine St, Los Angeles, CA
    Mission Street at Valencia Street, San Francisco, CA
    Hollywood & Vine, Los Angeles, CA, 90028
    Hollywood Blvd and Vine St, Los Angeles, CA, 90028
    Mission Street at Valencia Street, San Francisco, CA, 90028
    
==== License

    Copyright (c) 2007 Riderway (Derrek Long, Nicholas Schlueter)

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

==== Notes
    If parts of the address are omitted from the original string 
    the accessor will be nil in StreetAddress::US::Address.
    
    Example:
    address = StreetAddress::US.parse("1600 Pennsylvania Ave, washington, dc")
    assert address.postal_code.nil?
    
==== Acknowledgements
    
    This gem is a near direct port of the perl module Geo::StreetAddress::US
    originally written by Schuyler D. Erle.  For more information see
    http://search.cpan.org/~sderle/Geo-StreetAddress-US-0.99/
    
=end


module StreetAddress
  class US
    VERSION = '1.0.3'

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
      def parse(location, args = {})
        if Regexp.new(corner_regexp, Regexp::IGNORECASE).match(location)
          parse_intersection(location)
        elsif args[:informal]
          parse_address(location) || parse_informal_address(location)
        else 
          parse_address(location);
        end
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

=begin rdoc
  
    This is class returned by StreetAddress::US::parse, StreetAddress::US::parse_address 
    and StreetAddress::US::parse_intersection.  If an instance represents an intersection
    the attribute street2 will be populated.
  
=end
    class Address
      attr_accessor(
        :number, 
        :street, 
        :street_type, 
        :unit, 
        :unit_prefix, 
        :suffix, 
        :prefix, 
        :city, 
        :state, 
        :postal_code, 
        :postal_code_ext, 
        :street2, 
        :street_type2, 
        :suffix2, 
        :prefix2
      )

      def initialize(args)
        args.keys.each do |attrib| 
          self.send("#{attrib}=", args[attrib]) 
        end
        return
      end

      def state_name
        name = StreetAddress::US::STATE_NAMES[state] and name.capitalize
      end

      def intersection?
        !street2.nil?
      end

      def line1(s = "")
        s += number
        s += " " + prefix unless prefix.nil?
        s += " " + street unless street.nil?
        s += " " + street_type unless street_type.nil?
        if( !unit_prefix.nil? && !unit.nil? )
          s += " " + unit_prefix 
          s += " " + unit
        elsif( unit_prefix.nil? && !unit.nil? )
          s += " #" + unit
        end
        s += " " + suffix unless suffix.nil?
        return s
      end

      def to_s(format = :default)
        s = ""
        case format
        when :line1
          s += line1(s)
        else
          if intersection?
            s += prefix + " " unless prefix.nil?
            s += street 
            s += " " + street_type unless street_type.nil?
            s += " " + suffix unless suffix.nil?
            s += " and"
            s += " " + prefix2 unless prefix2.nil?
            s += " " + street2
            s += " " + street_type2 unless street_type2.nil?
            s += " " + suffix2 unless suffix2.nil?
            s += ", " + city unless city.nil?
            s += ", " + state unless state.nil?
            s += " " + postal_code unless postal_code.nil?
          else
            s += line1(s)
            s += ", " + city unless city.nil?
            s += ", " + state unless state.nil?
            s += " " + postal_code unless postal_code.nil?
            s += "-" + postal_code_ext unless postal_code_ext.nil?
          end
        end
        return s
      end  
    end
  end
end
