#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;
use JSON;
use Data::Dumper;
use v5.10;

# Load OSM file
my $osm_ref = XMLin(
   'data.osm',
   ForceArray => 1,
   KeyAttr    => ['id', 'k'],
   ValueAttr  => ['ref'],
);

# ------------------------------------------------------------------------
# Convert all OSM polygons into a list of lat-lon pairs with the final
# lat-lon pair removed

my %polys;

foreach my $way_id (keys %{$osm_ref->{way}}) {

   # Get way Perl data info
   my $way_ref    = $osm_ref->{way}{$way_id};

   # Get way's imagery group name and color
   my $group_name = $way_ref->{tag}{name}{v} || '';
   my $color_code = $way_ref->{tag}{color}{v} || '';

   # Get list of lat-lons for the way
   my @latlons;
   foreach my $node_id (@{$way_ref->{nd}}) {
      my $node_ref = $osm_ref->{node}{$node_id};
      my $lat      = $node_ref->{lat};
      my $lon      = $node_ref->{lon};
      push @latlons, [$lat, $lon];
   }
   pop @latlons; # Remove final lat-lon pair

   # Add way data to polygon cache
   $polys{$way_id} = {
      group   => $group_name,
      color   => $color_code,
      latlons => \@latlons,
   };
}

# ------------------------------------------------------------------------
# Process multipolygons

my @multipolys;

foreach my $relation_ref (values %{$osm_ref->{relation}}) {

   # Skip non-multipolygons
   next if !exists $relation_ref->{tag}
      || !exists $relation_ref->{tag}{type}
      || $relation_ref->{tag}{type}{v} ne 'multipolygon';

   # Get the lat-lons for the ways of the relation using the polygon
   # cache and remove from the cache. Create a list of the list of
   # lat-lons for the member ways with the outer way's list as the first
   # list item. Get and the imagery group name too
   my @latlons_list;
   my $group_name;
   my $color_code;
   foreach my $member_ref (@{$relation_ref->{member}}) {
      given ($member_ref->{role}) {
         when ('outer') {
            unshift @latlons_list, $polys{$member_ref->{ref}}{latlons};
            $group_name = $polys{$member_ref->{ref}}{group};
            $color_code = $polys{$member_ref->{ref}}{color};
         }
         when ('inner') {
            push @latlons_list, $polys{$member_ref->{ref}}{latlons};
         }
      }
      delete $polys{$member_ref->{ref}};
   }

   # Add multipolygon data to multipolygon cache
   push @multipolys, {
      group        => $group_name,
      color        => $color_code,
      latlons_list => \@latlons_list,
   };
}

# ------------------------------------------------------------------------
# Construct JSON data

# Collect each outline group
my %pre_json;
foreach my $poly_ref (values %polys) {
   if (!exists $pre_json{$poly_ref->{group}}) {
      $pre_json{$poly_ref->{group}} = [];
   }
   push @{$pre_json{$poly_ref->{group}}}, {
      color   => $poly_ref->{color},
      latlons => [$poly_ref->{latlons}],
   };
}
foreach my $multipoly_ref (@multipolys) {
   if (!exists $pre_json{$multipoly_ref->{group}}) {
      $pre_json{$multipoly_ref->{group}} = [];
   }
   push @{$pre_json{$multipoly_ref->{group}}}, {
      color   => $multipoly_ref->{color},
      latlons => $multipoly_ref->{latlons_list},
   };
}

# Create JSON object as a list of groups
my @json;
foreach my $group_name (sort keys %pre_json) {
   push @json, {
      group => $group_name,
      polys => $pre_json{$group_name},
   };
}

# Output JSON as a Javascript variable assignment
my $json_obj = JSON->new;
print "var data = ", $json_obj->pretty->encode(\@json);
