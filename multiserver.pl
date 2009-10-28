#!/usr/bin/env perl
use strict;
use FindBin '$RealBin';
use lib "$RealBin/lib";
BEGIN {
    my $want = '';
    eval { require 'JSON/XS.pm' } or $want .= "Please install the JSON::XS module first.\n";
    eval { require 'Data/UUID.pm' } or $want .= "Please install the Data::UUID module first.\n";
    die $want if $want;
}
use POE qw(Component::Server::Bayeux);

my $server = POE::Component::Server::Bayeux->spawn(
    Port  => 8080,
    Alias => 'MultiSocialCalc',
);
$poe_kernel->run();
