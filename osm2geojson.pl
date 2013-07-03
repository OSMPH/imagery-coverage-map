#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;
use JSON;
use v5.10;

# ---------------------------------------------------------------------------

# Load OSM file
my $Osm_Ref = XMLin(
   'data.osm',
   ForceArray => 1,
   KeyAttr    => ['id', 'k'],
   ValueAttr  => ['ref'],
);

# ---------------------------------------------------------------------------

# Convert all OSM polygons into a hash where the key is the OSM way ID and
# the value is a hash containing the OSM way's name=* tag value (the outline
# group it belongs to) and the way's list of positions.
# Also collect the group colors.

my %Positions_Array_Data;
my %Group_Colors;

foreach my $way_id (keys %{$Osm_Ref->{way}}) {

   # Get way Perl data info
   my $way_ref = $Osm_Ref->{way}{$way_id};

   # Get way's imagery group name and color
   my $group_name = $way_ref->{tag}{name }{v} || '';
   my $color_code = $way_ref->{tag}{color}{v} || '';
   $Group_Colors{$group_name} = $color_code;

   # Get array of positions for the way
   my @positions_array;
   foreach my $node_id (@{$way_ref->{nd}}) {
      my $node_ref = $Osm_Ref->{node}{$node_id};
      my $lat      = $node_ref->{lat};
      my $lon      = $node_ref->{lon};
      push @positions_array, [$lon+0, $lat+0];  # Numerify coordinates
   }

   # Add to positions array hash
   $Positions_Array_Data{$way_id} = {
      group           => $group_name,
      positions_array => \@positions_array,
   };
}

# ---------------------------------------------------------------------------

# Convert OSM multipolygons into a list where each item is a hash containing
# the outer way's name=* tag value and an array of each member way's list of
# of positions. This data is obtained and removed from the positions array
# hash earlier.

my @Polygons_Data;  # GeoJSON meaning of "Polygon"

foreach my $relation_ref (values %{$Osm_Ref->{relation}}) {

   # Skip non-OSM multipolygons
   next if !exists $relation_ref->{tag}
      || !exists $relation_ref->{tag}{type}
      || $relation_ref->{tag}{type}{v} ne 'multipolygon';

   # Get the positions for the ways of the relation using the positions array
   # hash and remove them from that hash. Create an array of position arrays
   # for the member ways with the outer way's array as the first item.
   # Get the imagery group name too.
   my @positions_array_array;
   my $group_name;
   foreach my $member_ref (@{$relation_ref->{member}}) {

      my $member_id           = $member_ref->{ref};
      my $data_ref            = $Positions_Array_Data{$member_id};
      my $positions_array_ref = $data_ref->{positions_array};

      given ($member_ref->{role}) {
         when ('outer') {
            unshift @positions_array_array, $positions_array_ref;
            $group_name = $data_ref->{group};
         }
         when ('inner') {
            push @positions_array_array, $positions_array_ref;
         }
      }

      delete $Positions_Array_Data{$member_id};
   }

   # Add to polygons list
   push @Polygons_Data, {
      group                 => $group_name,
      positions_array_array => \@positions_array_array,
   };
}

# ------------------------------------------------------------------------

# Initialize hash of GeoJSON features, 1 item for each of the known groups

my %Features;

foreach my $group_name (keys %Group_Colors) {

   # Skip empty group names (created from OSM inner polygons)
   next if $group_name eq '';

   $Features{$group_name} = {
      type       => 'Feature',
      id         => $group_name,
      geometry   => {
         type        => 'MultiPolygon',
         coordinates => [],
      },
      properties => {
         color => $Group_Colors{$group_name},
      }
   };
}

# Process GeoJSON simple Polygon objects
foreach my $data_ref (values %Positions_Array_Data) {
   my $group_name = $data_ref->{group};
   push @{$Features{$group_name}{geometry}{coordinates}}, [$data_ref->{positions_array}];
}

# Process GeoJSON multiple-ring Polygon objects
foreach my $data_ref (@Polygons_Data) {
   my $group_name = $data_ref->{group};
   push @{$Features{$group_name}{geometry}{coordinates}}, $data_ref->{positions_array_array};
}

# Construct final GeoJSON structure
my %Json = (
   type     => 'FeatureCollection',
   features => [@Features{sort keys %Features}],
);

# Output GeoJSON
open my $fh, '>', 'data.geojson' or die ($!);
print {$fh} JSON->new->pretty->encode(\%Json);
