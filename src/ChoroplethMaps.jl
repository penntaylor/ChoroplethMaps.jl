module ChoroplethMaps

using DataFrames
using Proj4
using Gadfly

export mapify, choroplethmap, choroplethlayer, Provider


include("providers/provider.jl")

"""
`mapify(df::DataFrame, provider::Provider.AbstractProvider;
 key::Symbol=:GEOID, plotgroup::Symbol=:blank_symbol,
 projection::Int=3857, keepcols=[])`

Takes in a DataFrame and returns a new DataFrame containing polygons pulled
from the `provider`'s geodata, suitable for plotting with Gadfly.

`df` is the input DataFrame which will be joined with the `provider` polygons,
using field `key` as the join key. `key` MUST exist in both `df` and
`provider`.

`plotgroup` is the `provider` field that differentiates unique shapes,
and need only be specfied if it differs from `key`. `projection` is
an EPSG numeric code specifying the desired projection of the choropleth map;
the default is EPSG:3857 "Web Mercator". `keepcols` specifies any additional
columns (as symbols) from the provider that should be kept in the returned
DataFrame

Example:

    df = DataFrame(NAME=["Alabama","Mississippi"], POP=[4849000, 2994000])
    mapframe = mapify(df, Provider.statesummary(), key=:NAME)
    # Then to plot with Gadfly:
    plot(mapframe, x=:CM_X, y=:CM_Y, group=:NAME, color=:POP,
      Geom.polygon(preserve_order=true, fill=true),
      Coord.cartesian(fixed=true))
"""
function mapify(df::DataFrame, provider::Provider.AbstractProvider;
                  key::Symbol=:GEOID,
                  plotgroup::Symbol=:blank_symbol,
                  projection::Int=3857,
                  keepcols=[])

  polygons = DataFrame(CM_POLYGONS=Provider.polygons(provider))
  records = DataFrame(Provider.records(provider))
  if plotgroup == :blank_symbol
    plotgroup = key
  end
  dropallbut!(records, vcat(unique([key,plotgroup]), keepcols))
  pdata = hcat(records, polygons)

  joined = join(df, pdata, on=key, kind=:inner)
  joined = splitmultipolygons(joined, plotgroup)

  newdf = add_xy_cols!(similar(joined, 0))
  delete!(newdf, :CM_POLYGONS)

  projfrom = Projection(Proj4.epsg[Provider.projection(provider)])
  projto = Projection(Proj4.epsg[projection])

  for row in eachrow(joined)
    for pt in row[:CM_POLYGONS]
      copyrow!(newdf, row, exclude=[:CM_POLYGONS])

      # TODO: check that transform short-circuits if projfrom == projto
      tpt = transform(projfrom, projto, pt)

      push!(newdf[:CM_X], tpt[1])
      push!(newdf[:CM_Y], tpt[2])
    end
  end

  return newdf
end


"""
`choroplethmap(df::DataFrame, args...; group::Symbol=:NAME, color::Symbol=:feature, namedargs...)`

Produces a Gadfly plot using a mapify'd DataFrame. `group` refers to the
column in `df` that identifies the shapes to be plotted (it "groups" the
polygon points), and `color` refers to the column containing the statistic
of interest for the choropleth map. `args` and `namedargs` are optional, and
are passed through to Gadfly.plot untouched.
"""
function choroplethmap(df::DataFrame, args...; group::Symbol=:NAME, color::Symbol=:feature, namedargs...)
  Gadfly.plot(df, x=:CM_X, y=:CM_Y, group=group, color=color,
       Geom.polygon(preserve_order=true, fill=true),
       Coord.cartesian(fixed=true), args...; namedargs...)
end


"""
`choroplethlayer(df::DataFrame, args...; fill::Bool=true, group::Symbol=:NAME, color::Symbol=:feature, namedargs...)`

Similar to `choroplethmap`, but produces a layer suitable for passing into
Gadfly.plot. `fill` controls whether the polygons in the layer are filled
or merely outlines. You likely will want to add
`Coord.cartesian(fixed=true)` to your Gadfly.plot call.
"""
function choroplethlayer(df::DataFrame, args...; fill::Bool=true, group::Symbol=:NAME, color::Symbol=:feature, namedargs...)
  if fill
    Gadfly.layer(df, x=:CM_X, y=:CM_Y, group=group, color=color,
                 Geom.polygon(preserve_order=true, fill=fill), args...; namedargs...)
  else
    # Omit the color aesthetic, since it makes no sense here and may not have
    # been passed in at all
    Gadfly.layer(df, x=:CM_X, y=:CM_Y, group=group,
                 Geom.polygon(preserve_order=true, fill=fill), args...)
  end
end


function dropallbut!(df, keep)
  for name in names(df)
    !(name in keep) && delete!(df, name)
  end
end


function add_xy_cols!(df)
  lat = DataArray(Float64[], Bool[])
  lon = DataArray(Float64[], Bool[])
  insert!(df, 1, lat, :CM_Y)
  insert!(df, 1, lon, :CM_X)
end


# Political boundaries often contain multiple polygons buried inside a single
# "polygon" that thematically represent pieces of the same unit; eg. a territory
# with islands. To ensure these are rendered correctly, these have to be split
# up while still maintaining all other associated data.
function splitmultipolygons(df, key)

  indices = findindices(df)

  # "Convert" key column into a string so we can safely append an ordered tag
  # that will be used for render grouping
  newkeys = AbstractString[ string(k) for k in df[key] ]
  rename!(df, key, :CM_ORIG_KEY)
  insert!(df, 1, DataArray(newkeys), key)
  newdf = similar(df, 0)

  for (row, polyindices) in zip(eachrow(df), indices)
    polyset = row[:CM_POLYGONS]
    for (pidxs, idx) in zip(polyindices, collect(1:length(polyindices)))
      copyrow!(newdf, row, exclude=[:CM_POLYGONS, key])
      push!(newdf[key], "$(row[key])_$idx")
      start, finish = pidxs
      push!(newdf[:CM_POLYGONS], polyset[start:finish])
    end
  end
  return newdf
end


function findindices(df)
  indices = Array{Array{Int64}}[]
  for row in eachrow(df)
    polygon = row[:CM_POLYGONS]
    rowindices = Array{Int64}[]
    idx = 1
    while idx < length(polygon)
      start = idx
      opener = polygon[idx]
      idx += 1 # begin search at next index
      while polygon[idx] != opener && idx != length(polygon)
        idx += 1
      end
      push!(rowindices, Int64[start, idx])
      idx += 1
    end
    push!(indices, rowindices)
  end
  return indices
end


function copyrow!(df, row; exclude=Symbol[])
  for name in names(row)
    !(name in exclude) && push!(df[name], row[name])
  end
end


end # module
