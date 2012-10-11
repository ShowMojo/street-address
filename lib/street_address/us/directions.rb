module StreetAddress::US::Directions
  DIRECTIONS = {
    "north" => "N",
    "northeast" => "NE",
    "east" => "E",
    "southeast" => "SE",
    "south" => "S",
    "southwest" => "SW",
    "west" => "W",
    "northwest" => "NW"
  }
  DIRECTION_CODES = DIRECTIONS.invert
end
