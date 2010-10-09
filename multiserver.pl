#!/usr/bin/env perl
BEGIN { system("sudo perl socketpolicy.pl &") };
use strict;
use Plack::Runner;

my $runner = Plack::Runner->new;
$runner->parse_options(-s => Feersum => -p => 9999);
$runner->run;
