---
layout: post
title:  "Geofencing - Part 2"
date:   2012-09-10 12:00:00
---

# Building Your Own Geofence Server

Well, it looks like I might have peaked your interest enough from the
previous post for you to keep reading. Good for me! If you've stumbled
across this post, then you might want to know that it is part of a series
(of which you are reading part 2). If you wish to read (or re-read) part
1, you can do so [here][1].

In this post, I'm going to walk you through the mechanics of creating a
(very) simple geofence server. We'll start first with the conceptual
approach that we will be taking, then we'll see how we can make those
ideas a reality. And, when it is all said and done, I have a little
surprise for you.


# Conceptual Approach

Before we get into the nitty-gritty details, we'll go over the conceptual
approach that we will be taking. My hope is that the theoretical foundation
will aid in understanding the concrete details. 

### Utilizing Mongo

As we're planning our geofence server, we know we want to use existing
technologies, where possible, to aid in development time. In this example,
we're going to use some of the geo-spatial indexing and search features
that are available in Mongo. 

In particular, Mongo allows you index Lat-Lon points and search within
a specified radius. To visualize this, I've put together a map full of
points (on the left) and a nearby-search query with a specified radius
(on the right) for you below.

![Mongo geo-spatial index and query visualization][2]

Although Mongo does not currently provide support for full-featured 
geofences, this particular feature will save us a lot of time as we
build our own geofence server.

### Geofences as Grids

Knowing that we can utilize Mongo's geo-spatial indexing capabilities
with points, we now have to think about how we can store our geofence
within Mongo as a set of points (so that we can most take advantage
of the hard work that the open source community has put into Mongo).

My approach is to visualize that we are drawing our geofence (really
just a polygon) on a grid. Then we can estimate our polygon by using
only the grid-blocks that lie within the polygon (or at least their
center-points lie within the polygon). We can then take the estimated
polygon (the set of grid-blocks) and get their center-points. It is these
center-points which we can then store in Mongo.

![polygon estimation with grids, grid-blocks, and center-points][3]

You might thinking that this is all fine and dandy, but how are we going to
use this to determine if someone or something is inside or outside of the
fence?

Simple! If we think of each point as the conceptual grid-block, from which
the point was derived, then we can do a nearby-search in Mongo with a
radius of one-half the length of the diagonal of the grid-block (plus a
little extra to account for some rare edge-cases). To illustrate:

![polygon query with points and nearby-search][4]

Voilà! Now if you search the points (your geofence) with a specific point
and the pre-determined radius, you'll either get back 0 points (meaning
that you are outside of the fence) or 1 to 4 points (meaning that you are
inside of the fence).

### Turning Polygons into Grids
So far, things have been pretty easy (although possibly not easy to follow
along the first time through) conceptually. Now you might have to get some
pin a paper out to draw this next piece to fully understand how we are
going to do this. 

Our objective is to turn a random, regular polygon into a set of grid-blocks
which estimate its shape. We're going to be using an algorithm similar to
how you get the [area of a polygon][5]. I'll give you the steps, then I'll
lay it out visually for you.

0. Create an array to contain your estimated polygon (array of grid-blocks),
we'll call it __E__
0. Generate a grid that contians your polygon
0. For each latitude (y-value on an x-y plane), draw a horizontal line
0. For each area in-between the horizontal lines:
    1. Get all grid-blocks that are between the lines, we'll call this list __G__
    1. Get all lines that intersect the horizontal-section, and for each one, called __l__:
        0. Get all grid-blocks in __G__ to the left of __l__, called __G<sub>2</sub>__
        0. For each grid-block in __G<sub>2</sub>__, called __g__:
            0. If __g__ is in __E__, remove __g__ from __E__
            0. If __g__ is not in __E__, add __g__ to __E__
0. Store grid-block center-points from __E__ in Mongo. Done!

<br />
If you didn't quite follow that (or can't visualize that well), then no
worries. Here is a visual:

![detailed estimation visualization 1][6]
![detailed estimation visualization 2][7]
![detailed estimation visualization 3][8]


# Coding Time

Okay, now that we have gone through evertyhing at the conceptual level, it's
time for some real code. If you had any trouble understanding the previous
sections, it will be worth your time to go back with pen and paper and draw
out all of the steps until it makes sense.

## Creating Our Grid

Assuming that we're going to get out polygon in the form of some Lat-Lon
points, then we can generate our grid like the following:

{% highlight ruby linenos %}
# Assuming that the coordinates for the polygon adhere to the
# format of:
# [
#   [:lon, :lat],
#   [:lon, :lat],
#   ...
# ]
#
# We can use the following methods:
 
 
 
# Method to get the min and max values for the polygon (plus
# some padding) that the grid can be generated within
def get_bounding_box(coords)
  # get max and min coords
  max = coords.inject({lat:0, lon:0}) do |max, c|
    max[:lon] = c[0] if c[0] > max[:lon]
    max[:lat] = c[1] if c[1] > max[:lat]
    max
  end
  min = coords.inject({lat:MAX_LAT, lon:MAX_LON}) do |min, c|
    min[:lon] = c[0] if c[0] < min[:lon]
    min[:lat] = c[1] if c[1] < min[:lat]
    min
  end
  # add a little padding to the max and min
  max.each {|k, v| max[k] += 1 }
  min.each {|k, v| min[k] -= 1 }
 
  {min: min, max: max}
end
 
 
# We need to create a conceptual grid in which to do our estimation
# against. We're actually going to represent our grid-blocks by their
# centerpoint. Ex:
# 
#  _______
# |       |
# |   +   |  -- Box and center-point
# |_______|
# 
# We're representing our blocks as points because that's how we're
# going store and index our fence in Mongo when it's all said and
# done.
# 
# Note: In real-life, we might want to adjust the size of the grid-block
#       based on how large the geofence is, how granular your estimation
#       will be, etc. For this example, we're going to use a fixed size
#       grid block of  0.5 x 0.5
def generate_grid(bounds)
  lon_range = bounds[:min][:lon]...bounds[:max][:lon]
  lat_range = bounds[:min][:lat]...bounds[:max][:lat]
 
  grid = []
  lon_range.each do |lon|
    lat_range.each do |lat|
      grid << [lon + 0.25, lat + 0.25]
      grid << [lon + 0.25, lat + 0.75]
      grid << [lon + 0.75, lat + 0.25]
      grid << [lon + 0.75, lat + 0.75]
    end
  end
 
  grid
end
 
 
 
# And they would be called like so:
bounds = get_bounding_box(coords)
grid = generate_grid(bounds)
{% endhighlight %}


## Getting our Horizontal Sections

{% highlight ruby linenos %}
# The horizontal sections generated are the spaces in-between each
# pair of contiguous horizontal lines (derived from the latitude
# value).
#
# Horizontal sections in format of:
# [
#   [<latN>, <lat1>],
#   [<lat1>, <lat2>],
#   ..., 
#   [<latN-1>, <latN>]
# ]
def get_horizontals(coords)
  #get all individual horizontals
  h1 = coords.inject([]) do |arr, (lon, lat)|
    arr << lat unless arr.include? lat
    arr
  end
 
  #wrap those individuals up into cyclic pairs
  h1.sort!
  h2 = h1.dup
  h1.pop
  h2.shift
  h1.zip(h2)
end
{% endhighlight %}

Once we have our horizontal sections, we can then filter our grid-items to
only process those that are included in the sub-section. This would look
something like:

{% highlight ruby linenos %}
horizontals = get_horizontals(coords)
 
horizontals.each do |horizontal|
  sub_grid = grid.select do |g|
    g.last.between?(horizontal.first, horizontal.last)
  end
 
  # ... some more processing...
end
{% endhighlight %}


## Intersecting Lines

Alright! Now we just need to get the intersecting lines though the sub-grid
and we'll be one step away from adding grid-blocks into our estimated polygon
array. (If you don't know what I'm talking about, please review the conceptual
aproach, and visuals, above.)

{% highlight ruby linenos %}
# Given a horizonal (two lat points) and the set of lines that constitute
# our polygon, determine what lines intersect the space created by the
# horizontal (or horizontal sub-section if you prefer to think of it that
# way)
# 
# 
# ---*------------------------------------------------
#     \
#      \  - intersecting line           [horizontal section]
#       \
# -------*--------------------------------------------
#        |
#        |
#        |   
#        ... 
# 
# 
# h  = horizontal
# ls = lines
def intersecting_lines(h, ls) 
  ls.select do |l| 
    l.first.last <= h.first && l.last.last >= h.last
  end 
end
 
 
 
# The "lines" is the set of all lines for the polygon.
lines = coords.zip(coords.dup.rotate(-1))
lines.map! {|l| l.sort! {|a,b| a.last <=> b.last } }
 
# Assuming that we already have our horizontals
horizontals.each do |horizontal|
  intersects = intersecting_lines(horizontal, lines)
  # ... more processing ...
end
{% endhighlight %}


## Is a Point to the Left or Right?

Now that we can get out intersecting lines, we need to determine, for each
point within the sub-grid, if that point is to the left of the intersecting
line or to the right of the line. If it is to the left of the line, then
two things can happen. If that point is already included in the 
estimated-polygon array, then it will be removed and if it was not in the
array, then it will be added. And finally, the code:

{% highlight ruby linenos %}
# Get the determinant of a line and a point. This is conceptually
# represented by the following:
# 
# point = (a,b)
# line  = [(x1, y1), (x2, y2)], such that y2 > y1
# 
# matrix:
# | (x2 - x1)    (a-x1) |
# | (y2 - y1)    (b-y1) |
# 
# determinent: 
#   (x2 - x1)*(b-y1)  -  (y2-y1)*(a-x1)
# 
# 
# Assertions:
#   determinent > 0  <->  point lies to left of line
#   determinent = 0  <->  point lies on the line
#   determinent < 0  <->  pont lies to right of line
#
# Line:  [[x1,y1],[x2,y2]]
# Point: [a,b]
def self.det(line, point)
  x1 = line.first.first
  y1 = line.first.last
 
  x2 = line.last.first
  y2 = line.last.last
 
  a = point.first
  b = point.last
 
  (x2 - x1)*(b-y1)  -  (y2-y1)*(a-x1)
end
 
 
 
# Process each grid-item for each intersecting line
estimated_polygon = []
intersecting_lines.each do |line|
  sub_grid.each do |grid_item|
    if det(line, grid_item) > 0
      if estimated_polygon.include?(grid_item)
        estimated_polygon.delete(grid_item)
      else
        estimated_polygon << grid_item
      end
    end
  end
end
{% endhighlight %}



## Estimation Complete!

While it may not seem like you are done, trust me when I say you have
completed all of the necessary steps to estimate a geofence. The only
thing missing is to put all of the steps together (stay tuned). Now
that we have our estimation, we simply need to store it in Mongo.



## Mongo-Land

Okay, now that we have our estimated polygon/fence, it's time to store
those points in Mongo-land. First, we need to understand what our
resulting estimation looks like:

{% highlight ruby linenos %}
[
  [:lon, :lat],
  [:lon, :lat],
  ...
]
{% endhighlight %}

The __:lon__ and __:lat__ would obviously be replaced with real values.
We're going to tranform this array of points to store in Mongo in the
following format:

{% highlight js linenos %}
{
  _id: ObjectId(),
  coordinates: [
    { lon: x, lat: y },
    { lon: x, lat: y },
    ...
  ]
}
{% endhighlight %}

We have to use this particular format because it is required for us to
apply our geo-spatial index (which I'll show in a moment). If you want more
info on Mongo's geo-spatial indexes, check out [their docs][9].

To store our estimated polygon/fence into mongo, we're going to use the
following code:

{% highlight ruby linenos %}
# Fence Document in Mongo looks like:
# {
#   _id: ObjectId(),#   coordinates: [
#     { lon: x, lat: y },
#     ...
#   ]
# }
def store_fence(fence)
  # TODO test mongo driver
  # convert fence from array to format above
  mongo_fence = []
  fence.each do |coord|
    mongo_fence << {
      lon: coord[0],
      lat: coord[1]
    }
  end
  # store fence in Mongo
  @coll.insert( { coordinates: mongo_fence } )
  # ensure the index is applied
  @coll.ensure_index([[:coordinates, Mongo::GEO2D]])
end
{% endhighlight %}



## Querying Mongo

Now that we have everything stored in Mongo, it's time to utilize the DB's
geo-spatial indexing features to bring out geofences to life! And it's so
simple; the code is only:

{% highlight ruby linenos %}
# Coord is of format:
# {
#   lon: x,
#   lat: y
# }
def within_fence?(coord)
  # search for fence in Mongo given coordinate
  radius = 0.26    # same as 0.5 ** 2 + 0.01
  @coll.find({
    coordinates: {
      :$near         => [coord[:lon], coord[:lat]],
      :$maxDistance  => radius
    }
  }).count > 1
end
{% endhighlight %}

Of course, I'm only returning if the count is greater than zero. You could
do whatever you please with the cursor. I think the cursor is nil if nothing
is found in Mongo, so you could just return the result of the find operation.




# Suprise!

It's time to find out what's at the end of the rainbow. I've been promising
_something_ this whole time. Well, you're just going to have to go to
the [third post][10] in the series to find out!  ;-)








  [1]: /log/2012/07/11/Geofencing--Part-1.md
  [2]: /blog-files/geofence/part-2/mongo-spatial-index-and-query.png
  [3]: /blog-files/geofence/part-2/polygon-estimation-conceptual.png
  [4]: /blog-files/geofence/part-2/polygon-query.png
  [5]: http://alienryderflex.com/polygon_area/
  [6]: /blog-files/geofence/part-2/polygon-estimation-detailed-1.png
  [7]: /blog-files/geofence/part-2/polygon-estimation-detailed-2.png
  [8]: /blog-files/geofence/part-2/polygon-estimation-detailed-3.png
  [9]: http://www.mongodb.org/display/DOCS/Geospatial+Indexing/
  [10]: /log/2012/09/10/Geofencing--Part-3.md
