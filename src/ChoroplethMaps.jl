module ChoroplethMaps

using DataFrames
using Proj4
using Gadfly
using Compose

export mapify, choroplethmap, choroplethlayer, graticule, Provider, projstr

# TODO: To be able to layer the plot over a background tile, use an invocation like this:
# compose(plot_context(), bitmap("image/png", Array{UInt8}(readall("price.png")), 0, 0, 1, 1))
# Hack this in with underguide perhaps?

include("providers/provider.jl")
include("graticule.jl")
include("underguide.jl")

"""
`mapify(df::DataFrame, provider::Provider.AbstractProvider;
 key::Symbol=:GEOID, plotgroup::Symbol=:blank_symbol,
 projection::AbstractString="epsg:3857", keepcols=[])`

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
                  projection::AbstractString="epsg:3857",
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

  newdf = add_xyp_cols!(similar(joined, 0))
  delete!(newdf, :CM_POLYGONS)

  projfrom = Projection(projstr(Provider.projection(provider)))
  projto = Projection(projstr(projection))

  for row in eachrow(joined)
    for pt in row[:CM_POLYGONS]
      copyrow!(newdf, row, exclude=[:CM_POLYGONS])

      # TODO: check that transform short-circuits if projfrom == projto
      tpt = transform(projfrom, projto, pt)

      push!(newdf[:CM_X], tpt[1])
      push!(newdf[:CM_Y], tpt[2])
      push!(newdf[:CM_P], projection)
    end
  end

  return newdf
end


"""
`choroplethmap(df::DataFrame, args...; group::Symbol=:NAME, color::Symbol=:feature, namedargs...)`

Produces a Gadfly plot using a mapify'd DataFrame. `group` refers to the
column in `df` that identifies the shapes to be plotted (it "groups" the
polygon points), and `color` refers to the column containing the statistic
of interest for the choropleth map. Set `graticule=false` to turn off the
default graticule. `args` and `namedargs` are optional, and
are passed through to Gadfly.plot untouched. This function sets up a number of
defaults for Gadfly. If you intend to heavily style your maps using
Gadfly.Theme, you may find it easier to copy the code from this function and
modify the underlying call to Gadfly.plot directly.
"""
function choroplethmap(df::DataFrame, args...; group::Symbol=:NAME, color::Symbol=:feature, graticule::Union{Compose.Context, Bool}=true ,namedargs...)
  if isa(graticule, Bool)
    graticule = graticule == false ? compose(context()) : ChoroplethMaps.graticule(df)
  end
  Gadfly.plot(df, x=:CM_X, y=:CM_Y, group=group, color=color,
              Geom.polygon(preserve_order=true, fill=true),
              Coord.cartesian(fixed=true),
              underguide(graticule),
              Guide.xticks( label=false), Guide.yticks( label=false),
              Guide.XLabel(""), Guide.YLabel(""),
              Theme(grid_color=colorant"rgba(0,0,0,0.0)"),
              args...; namedargs...)
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


"""
`projstr(str::AbstractString)`

Returns a Proj4 projection string based on the contents of `str`, which
can have any of the following forms:

* "EPSG:<wkid>"
* "ESRI:<wkid>"
* "<wkid>"
* "+proj=..."

In each of the first three forms, `<wkid>` refers to an integer well-known id.
The third form is provided as a convenience, but be aware that it may not
return the exact projection you expect -- it's better to specify the authority
explicitly as in the first two forms, if using a wkid.
The last form represents a valid Proj4 string, resulting in the contents
of `str` simply being returned as the result.
"""
function projstr(str::AbstractString)
  # Plain Proj4 string?
  m = match(r"\+proj"i, str)
  isa(m, RegexMatch) && return str

  # EPSG wkid?
  m = match(r"epsg:(\d+)"i, str)
  isa(m, RegexMatch) && return Proj4.epsg[parse(Int64, m.captures[1])]

  # ESRI wkid?
  m = match(r"esri:(\d+)"i, str)
  isa(m, RegexMatch) && return Proj4.esri[parse(Int64, m.captures[1])]

  try
    return projstr(parse(Int64, str))
  catch
    error("Unknown crs/srs: $str")
  end
end


"""
`projstr(wkid::Integer)`

Returns a Proj4 projection string based on the contents of `wkid`. First
tries to interpret the wkid as an EPSG code, and, if that fails, tries to
interpret it as an ESRI code.
"""
function projstr(wkid::Integer)
  try
    return Proj4.epsg[wkid]
  catch
    return Proj4.esri[wkid]
  end
end


function dropallbut!(df, keep)
  for name in names(df)
    !(name in keep) && delete!(df, name)
  end
end


function add_xyp_cols!(df)
  lat = DataArray(Float64[], Bool[])
  lon = DataArray(Float64[], Bool[])
  prj = DataArray(AbstractString[], Bool[])
  insert!(df, 1, prj, :CM_P)
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


function objdiff(a, b)
  typeof(a) != typeof(b) && error("Objects must be of same type to diff")
  return filter((f)->getfield(a, f) != getfield(b, f), fieldnames(a))
end



end # module
