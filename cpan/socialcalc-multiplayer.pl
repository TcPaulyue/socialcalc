#!/usr/bin/env perl
use strict;
use Plack::Runner;
use File::ShareDir 'dist_dir';
my $home = dist_dir('App-SocialCalc-Multiplayer');
my $runner = Plack::Runner->new;
$runner->parse_options(-p => 9999, "$home/app.psgi");
$runner->run;
