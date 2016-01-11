# using DataFrames
# using Gadfly
# using Proj4
# using Compose
# using ChoroplethMaps


function graticule(;longs::Union{Array, Range}=[],
                   lats::Union{Array, Range}=[],
                   src_srs="epsg:4326",
                   dst_srs="epsg:3857",
                   showlabels=true,
                   latoflonglabels=Void(),
                   longoflatlabels=Void())
  xs = sort(collect(longs))
  ys = reverse(sort(collect(lats))) # reverse is only to make debugging easier
  src_grid = [[x, y] for y in ys, x in xs]
  dst_grid = mapgrid(src_grid, src_srs, dst_srs)

  vlineary = [line(dst_grid[:,col]) for col in 1:size(dst_grid,2)]
  hlineary = [line(vec(dst_grid[row,:])) for row in 1:size(dst_grid,1)]
  lines = compose(context(), vlineary..., hlineary...)

  layers = [lines]

  if showlabels
    src_proj = Projection(projstr(src_srs))
    dst_proj = Projection(projstr(dst_srs))

    # Place labels at outside left and bottom edges if label pos was unspecified
    labelx = isa(longoflatlabels, Void) ? xs[1] : longoflatlabels
    labely = isa(latoflonglabels, Void) ? ys[end] : latoflonglabels

    texts = vcat(longlabels(xs, labely, src_proj, dst_proj),
                 latlabels(ys, labelx, src_proj, dst_proj))
    labels = compose(context(), texts..., fill(colorant"gray"), fontsize(9pt))
    push!(layers, labels)
  end

  return compose(layers..., stroke(colorant"gray"), linewidth(0.1mm), strokedash([0.5mm, 0.5mm]))
end


function graticule(df::DataFrame; src_srs="epsg:4326", other...)
  # Notice src_srs refers to the *grid*, not the DataFrame!
  dst_srs = df[1, :CM_P]
  lons, lats = ticksfrombbox(
                  mapbbox(
                    bbox(df),
                    dst_srs,
                    src_srs))
  labelx = lons[Integer(floor(size(lons,1) / 4))] # Left edge of original bbox
  labely = lats[Integer(ceil(size(lats,1) / 4))] # Bottom edge of original bbox
  return graticule(longs=lons, lats=lats, src_srs=src_srs, dst_srs=dst_srs,
                   latoflonglabels=labely, longoflatlabels=labelx; other...)
end


function longlabels(xs, y, src_proj, dst_proj)
  map(xs) do x
    px, py = transform(src_proj, dst_proj, [x, y])
    text(px, py, "$x", hcenter, vtop)
  end
end


function latlabels(ys, x, src_proj, dst_proj)
  map(ys) do y
    px, py = transform(src_proj, dst_proj, [x, y])
    text(px, py, "$y", hleft, vcenter)
  end
end


# function testgrid(prj)
#   Gadfly.set_default_graphic_size(25cm, 19cm)
#   df = DataFrame(NAME=["Arkansas", "Florida", "Mississippi", "Alabama", "Louisiana", "Tennessee", "Georgia", "South Carolina"], feature=[8.7,13.2,36.7,30.0,25.6,23.7,24.6,14.6])
#   mp = mapify(df, Provider.STATESUMMARY(), key=:NAME, projection=prj)

#   guido = graticule(mp)
#   guida = graticule(longs=-91.0:0.5:-89.0,
#                     lats=23.0:0.5:25,
#                     src_srs="epsg:4236", dst_srs=prj,
#                     latoflonglabels=22.5, longoflatlabels=-88.5)

#   choroplethmap(mp, group=:NAME, color=:feature, Guide.annotation(guido), #Guide.annotation(guida),
#                 Guide.xticks( label=false), Guide.yticks( label=false),  #removing ticks also removes zoom
#                 Guide.XLabel(""), Guide.YLabel(""), Theme(grid_color=colorant"rgba(0,0,0,0.0)"))
# end


function grid(df::DataFrame, gridcrs::AbstractString)
  datacrs = df[1, :CM_P]
  unprojgrid = gridfrombbox(
                 mapbbox(
                   bbox(df),
                   datacrs,
                   gridcrs))
  return (unprojgrid, mapgrid( unprojgrid, gridcrs, datacrs))
end


function bbox(df::DataFrame)
  return Array[[extrema(df[:CM_X])...], [extrema(df[:CM_Y])...]]
end


function mapgrid(grid, from::AbstractString, to::AbstractString)
  projfrom = Projection(projstr(from))
  projto = Projection(projstr(to))
  return map((el) -> (transform(projfrom, projto, el)...), grid)
end


function gridfrombbox(bbox)
  xs = gridondim(bbox, 1, 180)
  ys = gridondim(bbox, 2, 90)
  return [[x, y] for y in reverse(ys), x in xs]
end


function ticksfrombbox(bbox)
  xs = gridondim(bbox, 1, 180)
  ys = gridondim(bbox, 2, 90)
  return (xs, ys)
end


function gridondim(bbox, dim, bmax)
  rng = getrange(bbox, dim)
  allowed_steps = Any[0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 20, 30]
  step = allowed_steps[findfirst((s) -> rng / s <= 12, allowed_steps)]

  # expand the range by 50% in each direction to ensure graticule covers entire map
  c = mean(bbox[dim])
  s = lock(c - 1.5 * rng / 2, bmax)
  t = lock(c + 1.5 * rng / 2, bmax)

  low  = nudge(s, step, floor)
  high = nudge(t, step, ceil)
  return collect(low:step:high)
end


function lock(x, bmax)
  abs(x) > bmax && return sign(x) * bmax
  return x
end


function getrange(bbox, dim)
  return bbox[dim][2] - bbox[dim][1]
end


function nudge(x, step, func)
  return step * Integer(func(x / step))
end


# Map each of the 4 bbox corners into the new coordinate space and return
# a new bounding box in that cs.
function mapbbox(bbox, from::AbstractString, to::AbstractString)
  tfp = transform(Projection(projstr(from)), Projection(projstr(to)),
                  [[bbox[1][1] bbox[2][1]]; [bbox[1][2] bbox[2][1]];
                   [bbox[1][2] bbox[2][2]]; [bbox[1][1] bbox[2][2]]])

  return Array[[extrema(tfp[:, 1])...], [extrema(tfp[:, 2])...]]
end
