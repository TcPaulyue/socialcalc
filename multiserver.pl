#!/usr/bin/env perl
BEGIN { system("sudo perl socketpolicy.pl &") };
use strict;
use Plack::Runner;

print "Please connnect to: http://localhost:9999/\n";
my $runner = Plack::Runner->new;
$runner->parse_options(-s => Feersum => -p => 9999);
$runner->run;
