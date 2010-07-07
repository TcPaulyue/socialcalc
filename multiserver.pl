#!/usr/bin/env perl
BEGIN { system("sudo perl socketpolicy.pl &") };
use strict;
use Plack::Runner;

my $runner = Plack::Runner->new;
$runner->parse_options(-s => Twiggy => -p => 9999);
$runner->run;
