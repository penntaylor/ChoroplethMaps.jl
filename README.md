# ChoroplethMaps

Easy thematic mapping using Gadfly and datasets such as US Census Bureau's TIGER data.

## Installing

ChoroplethMaps and some of its dependencies are not yet registered with METADATA, so:

```julia
Pkg.clone("https://github.com/FugroRoames/Proj4.jl.git")
Pkg.build("Proj4")

Pkg.clone("https://github.com/penntaylor/DBaseReader.jl.git")
Pkg.clone("https://github.com/penntaylor/ChoroplethMaps.jl.git")

Pkg.add("ZipFile")
```

## Example use

```julia
using ChoroplethMaps
using DataFrames

# The data we want to map thematically
df = DataFrame(NAME=["Alabama", "Arkansas", "Louisiana", "Mississippi", "Tennessee"],
PCT=[26.6673430422, 15.6204437142, 32.4899197277, 37.5052896066, 17.0874767458] )

# Using `choroplethmap` function and `Provider` for low-res State boundary TIGER
choroplethmap(mapify(df, Provider.STATESUMMARY(), key=:NAME),
              group=:NAME, color=:PCT)
```

![Example](http://penntaylor.github.io/ChoroplethMaps.jl/images/example.svg)

Or you could make a direct call into Gadfly.plot instead of calling `choroplethmap`:
```julia
using Gadfly
plot(mapify(df, Provider.STATESUMMARY(), key=:NAME),
     x=:CM_X, y=:CM_Y, group=:NAME, color=:PCT,
     Geom.polygon(preserve_order=true, fill=true),
     Coord.cartesian(fixed=true))
```

## Maps are nice, but what's this package all about?

ChoroplethMaps provides three pieces for making choropleth, or thematic, maps:

* `Provider`s that download and manage geographic shape data and make the data associated with a given source accessible as a `Dict` within Julia.
* A `mapify` function that joins thematic data stored in a `DataFrame` with the polygons from a `Provider` in a way that allows Gadfly to plot a choropleth map.
* A convenience function, `choroplethmap`, that sets up sensible defaults for Gadfly and removes some of the tedium of specifying a plot.

## More details? Okay....

### Provider(s)

Currently there is a single `Provider` for TIGER datasets from the US Census Bureau which can be used to automatically download and parse TIGER data from 2010 or later, including the smaller "thematic" boundary datasets from 2014.


### Wait, I just looked at the ouput of `mapify`, and a bunch of columns from the Provider are missing....

That's by design. `mapify` strips the returned DataFrame down to the minimal set of columns needed to plot what you've asked it to "mapify". All columns that don't participate in the plot are just eating memory. Some of the TIGER datasets are huge, and there's little justification for leaving all that stuff sitting around. If you specifically want to keep extra columns, use the `keepcols` argument to `mapify`. See the next section for an example.


### Using a column from the Provider as the thematic data

If you want to use a column from the original data as the color feature, you need to do two things: pass the name of the column in the `keepcols` argument of `mapify`, and then specify that column as the `color` argument to either `choroplethmap` or `Gadfly.plot`. Here we indicate we want to retain the :ALAND column in the DataFrame returned by `mapify`:

```julia
mapify(somedataframe, someprovider, key=:GEOID, keepcols=[:ALAND])
```

### Joining on one key and plotting on another

When you want to group shapes based on a key other than the mapify join key (argument "key"), pass that key in as the plotgroup option to `mapify`. Here we `mapify` based on :STATEFP, but tell `mapify` to group the polygons based on the value of :GEOID:

```julia
mp = mapify(somedataframe, someprovider, key=:STATEFP, plotgroup=:GEOID, keepcols=[:ALAND])
```

A working example:

```julia
ndf = DataFrame(STATEFP=["06"])
mp = mapify(ndf, Provider.COUNTYSUMMARY(), key=:STATEFP, plotgroup=:GEOID, keepcols=[:ALAND])
choroplethmap( mp, group=:GEOID, color=:ALAND)
```
