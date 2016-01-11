using ChoroplethMaps
using DataFrames
using Base.Test

###############################################################################
# User-facing functionality:

pv = Provider.STATESUMMARY()
@test Provider.names(pv) == [:STUSPS, :AWATER, :LSAD, :AFFGEOID, :STATENS,
                             :GEOID, :ALAND, :STATEFP, :NAME]
@test Provider.projection(pv) == "epsg:4269"
@test size(Provider.polygons(pv), 1) == 52
@test Provider.polygons(pv)[1][1][1] == -118.593969

df = DataFrame(NAME=["Alabama", "California"],
       feature=[26.6673430422, 6.549492945] )

mp = mapify(df, pv, key=:NAME)
@test names(mp) == [:CM_X, :CM_Y, :NAME, :CM_ORIG_KEY, :feature]

# Does data look basically correct?
@test mp[1, :NAME] == "Alabama_1"
@test mp[1, :CM_X] == -9.848286458886575e6
@test mp[1, :CM_Y] == 3.7493855901445053e6
@test mp[1, :feature] == 26.6673430422

# High-level test of polygon splitting:
@test unique(mp[:NAME]) == ["Alabama_1", "California_1", "California_2",
                            "California_3", "California_4", "California_5",
                            "California_6"]


###############################################################################
# Non-user-facing functionality:

indices = ChoroplethMaps.findindices(DataFrame(CM_POLYGONS=Provider.polygons(pv)))
@test size(indices, 1) == 52
@test indices[1] == Array[[1,10], [11,19], [20,26], [27,43], [44,56], [57,467]]
@test indices[2] == Array[[1,10]]
