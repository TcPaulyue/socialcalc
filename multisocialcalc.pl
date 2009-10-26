#!/usr/bin/env perl
use strict;
use POE qw(Component::Server::Bayeux);

my $server = POE::Component::Server::Bayeux->spawn(
    Port  => 8080,
    Alias => 'MultiSocialCalc',
);
$poe_kernel->run();
