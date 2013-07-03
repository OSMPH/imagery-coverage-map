## Introduction

The **OSMPH Imagery Coverage Map** creates an HTML-based slippy map that shows the coverage of satellite/aerial imagery in the Philippines that is available for tracing by OpenStreetMap contributors.

The basic workflow for publishing such a map is as follows:

1. Create/edit the OSM file containing the imagery outlines.
2. Use **osm2geojson.pl** to convert the OSM file to a GeoJSON file.
3. Upload the files to a web server.


## Detailed workflow

### Create/edit the OSM file

1. Use an OSM editor to create the OSM file.

2. Each outline polygon should be closed and have the following tags:

   `name=*`  - The name of the group to which this outline belongs (e.g. "Bing")
   `color=*` - The HTML color for this outline. This can be any recognized CSS color string such as "`red`" or "`#FFFFFF`"

3. For multipolygons, create a relation with the tag `type=multipolygon` and have a single `role=outer` way and any number of `role=inner` ways. Tag the outer way in the same way as in step 2 and there is no need to add tags to the inner ways or the relation itself. It is also important that the outer and inner ways are closed polygons each.

4. The OSM file must be saved as a basic OSM file (not a change or history OSM file) and with the filename "data.osm".

### Use osm2geojson.pl to convert the OSM file

1. Run **osm2geojson.pl**. This script will open the data.osm file in the current directory and output a data.geojson file in the same directory. This script requires Perl 5.10 and above to execute properly.

2. Test the created file by opening the local index.html file in a web browser (preferably Firefox). The index.html and the data.geojson files need to be in the same directory. You need to have Internet access since the HTML file uses the Leaflet library, which is fetched from the Leaflet CDN.

### Upload the files

1. Upload index.html and data.geojson to a publicly-accessible web server.

2. If you want the Bing Maps Aerial base layers, do the following:

   1. Obtain a [Bing Maps API key](http://www.bingmapsportal.com/), then create a file named "bingkey.js" with the code below as its content (placing your API Key inside the quotes). Place this file in the same directory as index.html and data.geojson.

      ```javascript
      bingKey = "<Bing Maps API Key>";
      ```

   2. Download the [Leaflet Bing layer JavaScript](https://gist.github.com/1221998) under the filename "TileLayer.Bing.js" then place a copy into the same directory as index.html and data.geojson.

3. Test by accessing the uploaded index.html file in a web browser.
