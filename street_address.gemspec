$LOAD_PATH.unshift 'lib'
require 'street_address'

Gem::Specification.new do |s|
  s.name = "StreetAddress"
  s.version = StreetAddress::US::VERSION
  s.date = Time.now.strftime('%Y-%m-%d')
  s.summary = "Parse Addresses into substituent parts. This gem includes US only."
  s.authors = [
    "Derrek Long", 
    "Nicholas Schleuter"
  ]
  s.require_paths = ["lib"]
  s.email         = "derreklong@gmail.com"
  s.files         = %w( README.rdoc Rakefile LICENSE )
  s.files        += Dir.glob("lib/**/*")
  s.test_files    = Dir.glob("test/**/*")
  s.homepage      = "https://github.com/derrek/street-address"
  s.description = <<desc
StreetAddress::US allows you to send any string to parse and if the string is a US address returns an object of the address broken into it's substituent parts.

A port of Geo::StreetAddress::US by Schuyler D. Erle and Tim Bunce.
desc
end
