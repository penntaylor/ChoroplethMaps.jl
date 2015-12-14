###############################################################################
### ShapefileProvider
#
# ShapefileProvider's must have the following fields:
#
# basename::AbstractString -- basename of the shapefile; also used as cache
#                             directory
# url::AbstractString -- canonical url of the shapefile
#
# polygons:Array -- will store the polygons extracted from the .shp
#
# records::Dict -- will store the records extracted from the .dbf (if available)

function polygons(provider::ShapefileProvider)
  return provider.polygons
end


function records(provider::ShapefileProvider)
  return provider.records
end

function names(provider::ShapefileProvider)
  return collect(keys((records(provider))))
end


# I don't really like this Pythonic naming scheme, but since I specifically
# don't want to export the Provider pseudo-constructors (eg. Provider.STATE())
# and Julia doesn't provide a straightforward way to completely hide functions,
# this seems like a decent compromise.

function _localize(provider::ShapefileProvider)
  _iscached(provider) && return
  cachedir = joinpath(Pkg.dir("ChoroplethMaps"), "cache")
  zipname = joinpath(cachedir, string(provider.basename, ".zip"))
  mkpath(dirname(zipname))

  # Maybe use Requests.jl here instead?
  download(provider.url, zipname)

  _unzip(zipname, joinpath(cachedir, provider.basename))
end


function _iscached(provider::ShapefileProvider)
  if isdir(_getcachedir(provider))
    return isfile(_getshpfilepath(provider))
  end
  return false
end


function _getcachedir(provider::ShapefileProvider)
  return joinpath(Pkg.dir("ChoroplethMaps"), "cache", provider.basename)
end


function _getshpfilepath(provider::ShapefileProvider)
  return joinpath(_getcachedir(provider), "$(provider.basename).shp")
end


function _getdbffilepath(provider::ShapefileProvider)
  return joinpath(_getcachedir(provider), "$(provider.basename).dbf")
end


function _unzip(cfile, dir)
  reader = ZipFile.Reader(cfile)
  for file in reader.files
    ucname = joinpath(dir, file.name)
    mkpath(dirname(ucname))
    ucfile = open(ucname, "w")
    write(ucfile, readall(file))
    close(ucfile)
  end
  close(reader)
end


function _parseshapes(provider::ShapefileProvider)
  shpf = open(_getshpfilepath(provider)) do fd
    read(fd, Shapefile.Handle)
  end
  # ChoroplethMaps module expects polygon data to be a
  # Vector of Vector of Vector of Float64
  polygons = Vector[]
  for shape in shpf.shapes
    polygon = Vector[]
    for pt in shape.points
      push!(polygon, [pt.x, pt.y])
    end
    push!(polygons, polygon)
  end
  return polygons
end


function _parserecords(provider::ShapefileProvider)
  dbffile = _getdbffilepath(provider)
  if !isfile(dbffile)
    warn("No .dbf associated with shapefile $(provider.basename)!")
    return Dict()
  end
  return readdbf(dbffile)
end

###############################################################################
