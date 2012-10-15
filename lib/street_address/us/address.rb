=begin rdoc
  
    This is class returned by StreetAddress::US::parse, StreetAddress::US::parse_address 
    and StreetAddress::US::parse_intersection.  If an instance represents an intersection
    the attribute street2 will be populated.
  
=end
class StreetAddress::US::Address
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

  def valid?(options = {})
    if options[:informal]
      (number and street) or (options[:intersections] and street and street2)
    elsif options[:street_only]
      number and street and !(zip city state)
    else
      (
        (number and street) or (options[:intersections] and street and street2)
      ) and (
        postal_code or (city and state)
      )
    end
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
    return s unless valid?
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

  def as_json
    {}.tap do |ret|
      [
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
        :postal_code_ext
      ].each{|a| ret[a] = send(a) }
    end
  end
end
