require 'test/unit'
require 'yaml'
require 'street_address'

class StreetAddressUsTest < Test::Unit::TestCase
  def setup
    @address_fixtures = YAML.load_file("test/fixtures/addresses.yml")
    
    @good_addresses     = @address_fixtures["good_addresses"]
    @bad_addresses      = @address_fixtures["bad_addresses"]
    @complete_addresses = @address_fixtures["complete_addresses"]

    @good_intersections = @address_fixtures["good_intersections"]

    @int1 = "Hollywood & Vine, Los Angeles, CA"
    @int2 = "Hollywood Blvd and Vine St, Los Angeles, CA"
    @int3 = "Mission Street at Valencia Street, San Francisco, CA"

  end

  def test_zip_plus_4_with_dash
    addr = StreetAddress::US.parse("2730 S Veitch St, Arlington, VA 22206-3333")
    assert_equal "3333", addr.postal_code_ext
  end

  def test_zip_plus_4_without_dash
    addr = StreetAddress::US.parse("2730 S Veitch St, Arlington, VA 222064444")
    assert_equal "4444", addr.postal_code_ext
  end

  def test_informal_parse_normal_address
    a = StreetAddress::US.parse("2730 S Veitch St, Arlington, VA 222064444", :informal => true)
    assert_equal "2730", a.number
    assert_equal "S", a.prefix
    assert_equal "Veitch", a.street
    assert_equal "St", a.street_type
    assert_equal "Arlington", a.city
    assert_equal "VA", a.state
    assert_equal "22206", a.postal_code
    assert_equal "4444", a.postal_code_ext
  end

  def test_informal_parse_informal_address
    a = StreetAddress::US.parse("2730 S Veitch St", :informal => true)
    assert_equal "2730", a.number
    assert_equal "S", a.prefix
    assert_equal "Veitch", a.street
    assert_equal "St", a.street_type
  end

  def test_informal_parse_informal_address_trailing_words
    a = StreetAddress::US.parse("2730 S Veitch St in the south of arlington", :informal => true)
    assert_equal "2730", a.number
    assert_equal "S", a.prefix
    assert_equal "Veitch", a.street
    assert_equal "St", a.street_type
  end

  def test_parse_on_complete_addresses
    @complete_addresses.each do |a|
      addr = StreetAddress::US.parse(a["full"])
      puts a["full"]
      puts addr.as_json.inspect
      assert_equal addr.number,           a["number"]
      assert_equal addr.street,           a["street"]
      assert_equal addr.street_type,      a["street_type"]
      assert_equal addr.unit,             a["unit"]
      assert_equal addr.unit_prefix,      a["unit_prefix"]
      assert_equal addr.suffix,           a["suffix"]
      assert_equal addr.prefix,           a["prefix"]
      assert_equal addr.city,             a["city"]
      assert_equal addr.state,            a["state"]
      assert_equal addr.postal_code,      a["postal_code"]
      assert_equal addr.postal_code_ext,  a["postal_code_ext"]
    end
  end

  def test_parse_on_good_addresses
    @good_addresses.each do |a|
      assert_not_nil StreetAddress::US.parse(a), a
    end
  end

  def test_parse_on_good_intersections
    @good_intersections.each do |intersection|
      assert_not_nil StreetAddress::US.parse_intersection(intersection)
    end
  end

  def test_parse_on_bad_addresses
    @bad_addresses.each do |a|
      assert_nil StreetAddress::US.parse(a)
    end
  end

  def test_parse
    assert_equal StreetAddress::US.parse("&"), nil
    assert_equal StreetAddress::US.parse(" and "), nil

    addr = StreetAddress::US.parse_intersection(@int1)
    assert_equal addr.city, "Los Angeles"
    assert_equal addr.state, "CA"
    assert_equal addr.street, "Hollywood"
    assert_equal addr.street2, "Vine"
    assert_equal addr.number, nil
    assert_equal addr.postal_code, nil
    assert_equal addr.intersection?, true

    addr = StreetAddress::US.parse_intersection(@int2)
    assert_equal addr.city, "Los Angeles"
    assert_equal addr.state, "CA"
    assert_equal addr.street, "Hollywood"
    assert_equal addr.street2, "Vine"
    assert_equal addr.number, nil
    assert_equal addr.postal_code, nil
    assert_equal addr.intersection?, true
    assert_equal addr.street_type, "Blvd"
    assert_equal addr.street_type2, "St"

    addr = StreetAddress::US.parse_intersection(@int3)
    assert_equal addr.city, "San Francisco"
    assert_equal addr.state, "CA"
    assert_equal addr.street, "Mission"
    assert_equal addr.street2, "Valencia"
    assert_equal addr.number, nil
    assert_equal addr.postal_code, nil
    assert_equal addr.intersection?, true
    assert_equal addr.street_type, "St"
    assert_equal addr.street_type2, "St"

  end

end
