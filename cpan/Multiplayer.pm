package App::SocialCalc::Multiplayer;
use 5.008;
our $VERSION = 20091119;

use strict;
use warnings;
use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;

sub main {
    use File::Basename;
    use File::ShareDir 'dist_dir';
    my $home = dist_dir('App-SocialCalc-Multiplayer');

    my $chat_re = '[\w\.\-]+';

    my $app = Tatsumaki::Application->new([
        "/chat/($chat_re)/poll" => __PACKAGE__ . '::ChatPollHandler',
        "/chat/($chat_re)/mxhrpoll" => __PACKAGE__ . '::ChatMultipartPollHandler',
        "/chat/($chat_re)/post" => __PACKAGE__ . '::ChatPostHandler',
    ]);

    $app->template_path("$home/templates");

# TODO this should be part of core
    use Plack::Middleware::Static;
    $app = Plack::Middleware::Static->wrap($app, path => sub { s{^/+$}{/index.html}; m{^/(?!chat/)} }, root => $home);

    use Tatsumaki::Middleware::BlockingFallback;
    $app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

    use Tatsumaki::Server;
    Tatsumaki::Server->new(port => 9999)->run($app);
}

package App::SocialCalc::Multiplayer::ChatPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

use Tatsumaki::MessageQueue;

sub get {
    my($self, $channel) = @_;
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");
    $session = rand(1) if $session eq 'dummy'; # for benchmarking stuff
    $mq->poll_once($session, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

package App::SocialCalc::Multiplayer::ChatMultipartPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my($self, $channel) = @_;

    my $session = $self->request->param('session') || rand(1);

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->poll($session, sub {
        my @events = @_;
        for my $event (@events) {
            $self->stream_write($event);
        }
    });
}

package App::SocialCalc::Multiplayer::ChatPostHandler;
use base qw(Tatsumaki::Handler);

sub post {
    my($self, $channel) = @_;
    my $v = $self->request->params;
    Encode::_utf8_on($v->{$_}) for keys %$v;
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish($v);
    $self->write({ success => 1 });
}

1;

__END__

=encoding utf8

=head1 NAME

App::SocialCalc::Multiplayer - Multiplayer SocialCalc Server

=head1 SYNOPSIS

Run this in a host computer:

    % socialcalc-multiplayer.pl
    Accepting requests at http://0.0.0.0:9999/

Then connect to port 9999 with two or more browsers, and start collaboratively
edit a web-based spreadsheet.

=head1 DESCRIPTION

This is a convenient bundle around a prototypical Tatsumaki-SocialCalc
integration hack, demonstrated in a YAPC::Tiny talk for Chupei.pm during
late October 2009.

The presentation slides are available at:
L<http://pugs.blogs.com/talks/hopscotch-yapctiny.pdf>

=head1 AUTHORS

唐鳳 E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

This work is derived from the SocialCalc program:

    Copyright (C) 2009 Socialtext, Inc.
    All Rights Reserved.

The upstream source tree was derived from:

    http://github.com/DanBricklin/socialcalc

Other than the CPAL license asserted by copyright holders above (see 
F<socialcalc/LEGAL.txt> and F<socialcalc/LICENSE.txt>), 唐鳳 places no
additional copyright claims over the collaborative editing extensions,
as detailed in the paragraph below.

=head1 CC0 1.0 Universal

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to App-SocialCalc-Multiplayer.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=cut
