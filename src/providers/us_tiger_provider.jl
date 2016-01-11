type USTigerProvider <: ShapefileProvider

  kind::AbstractString
  year::Int
  basename::AbstractString
  url::AbstractString

  projection::AbstractString
  polygons::Array
  records::Dict

  function USTigerProvider(; kind::AbstractString="STATE",
                             year::Int=2015,
                             basename::AbstractString="",
                             url::AbstractString="")
    year < 2010 && error("year must be 2010 or greater")
    prov = new(kind, year, basename, url)
    prov.projection = "epsg:4269"  # TIGER data is NAD83 / EPSG:4269
    _localize(prov)
    prov.polygons = _parseshapes(prov)
    prov.records = _parserecords(prov)
    return prov
  end

end


function projection(provider::USTigerProvider)
  return provider.projection
end


# Nationwide kinds
for k in ["AIANNH", "AITSN", "ANRC", "CBSA", "CNECTA", "COASTLINE", "COUNTY", "CSA",
          "FACESMIL", "METDIV", "MIL", "NECTA", "NECTADIV", "PRIMARYROADS", "RAILS",
          "STATE", "TBG", "TTRACT"]
  @eval begin
    function ($(Symbol(k)))(; year::Int=2015)
      basename = "tl_$year\_us_$(lowercase($k))"
      url = "ftp://ftp2.census.gov/geo/tiger/TIGER$year\/$(uppercase($k))/.zip"
      return USTigerProvider(kind=($k), year=year, basename=basename, url=url)
    end
  end
end


# Geoid kinds
for k in ["AREAWATER", "EDGES", "FACES", "FACESAH", "LINEARWATER", "ROADS"]
  @eval begin
    function ($(Symbol(k)))(; year::Int=2015, geoid::AbstractString="01001")
      basename = "tl_$year\_$geoid\_$(lowercase($k))"
      url = "ftp://ftp2.census.gov/geo/tiger/TIGER$year\/$(uppercase($k))/$basename\.zip"
      return USTigerProvider(kind=($k), year=year, basename=basename, url=url)
    end
  end
end


# Statefp kinds
for k in ["AREALM", "BG", "COUSUB", "FACESAL", "PLACE", "POINTLM", "PRISECROADS", "SLDL",
          "SLDU", "TABBLOCK", "TRACT", "UNSD"]
  @eval begin
    function ($(Symbol(k)))(; year::Int=2015, statefp::AbstractString="01")
      basename="tl_$year\_$statefp\_$(lowercase($k))"
      url = "ftp://ftp2.census.gov/geo/tiger/TIGER$year\/$(uppercase($k))/$basename\.zip"
      return USTigerProvider(kind=($k), year=year, basename=basename, url=url)
    end
  end
end


# Summary kinds with 3 resolutions -- these generate functions with names like
# CBSASUMMARY, COUNTYSUMMARY, etc.
for k in ["CBSA", "CD114", "COUNTY", "CSA", "DIVISION", "NATION", "NECTA", "REGION", "STATE"]
  @eval begin
    function ($(Symbol(string(k,"SUMMARY"))))(; year::Int=2014, resolution::AbstractString="20m")
      resolutions = ["500k", "5m", "20m"]
      !(resolution in resolutions) && error("resolution must be one of $resolutions")
      basename = "cb_$year\_us_$(lowercase($k))_$resolution"
      url = "http://www2.census.gov/geo/tiger/GENZ$year\/shp/$basename\.zip"
      return USTigerProvider(kind=($k), year=year, basename=basename, url=url)
    end
  end
end


# Summary kinds with 500k resolution only
for k in ["COUNTY_WITHIN_CD114", "UA10", "ZCTA510"]
  @eval begin
    function ($(Symbol(string(k,"SUMMARY"))))(; year::Int=2014)
      basename = "cb_$year\_us_$(lowercase($k))_500k"
      url = "http://www2.census.gov/geo/tiger/GENZ$year\/shp/$basename\.zip"
      return USTigerProvider(kind=($k), year=year, basename=basename, url=url)
    end
  end
end


# These (non-summary) kinds have no polygon data. Consider ways to roll these in as shapeless types.
#geoidnonmap=["ADDR", "ADDRFEAT", "ADDRFN", "FEATNAMES"]
