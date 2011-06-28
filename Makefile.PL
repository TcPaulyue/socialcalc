#!/usr/bin/env perl
use ExtUtils::MakeMaker;

WriteMakefile(
  PREREQ_PM => { qw[
      File::ShareDir 0
      Fliggy 0
      JSON 0
      Protocol::WebSocket 0
      Try::Tiny 0
  ]}
);
