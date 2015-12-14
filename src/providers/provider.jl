module Provider

using ZipFile
using Shapefile
using DBaseReader

export polygons, records, projection, names, describenames

abstract AbstractProvider
abstract ShapefileProvider <: AbstractProvider

###############################################################################
#### All Provider's must implement these three functions
# to return the appropriate data
"""
`polygons(provider::AbstractProvider)`

Returns an array of polygons (shapes) associated with a provider
"""
function polygons(provider::AbstractProvider)
  return []
end

"""
`records(provider::AbstractProvider)`

Returns a `Dict` of records (without polygons) associated with a provider
"""
function records(provider::AbstractProvider)
  return Dict()
end

"""
`projection(provider::AbstractProvider)`

Returns the wkid of the Provider's projection as an `Int`
"""
function projection(provider::AbstractProvider)
  return 0
end

# And may optionally implement these two functions for returning record column
# names and descriptions
"""
`names(provider::AbstractProvider)`

Returns an array containing the names of the columns contained in the
Provider's records
"""
function names(provider::AbstractProvider)
  return []
end

"""
`describenames(provider::AbstractProvider)`

Returns a `Dict` associating a Provider's columns names with a description
of the column.
"""
function describenames(provider::AbstractProvider)
  return Dict()
end
###############################################################################

include("shapefile_provider.jl")
include("us_tiger_provider.jl")

end # module
