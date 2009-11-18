#!/usr/bin/env perl
use strict;
use warnings;
BEGIN {
    eval { require Tatsumaki } or die "Please install Tatsumaki from http://github.com/miyagawa/Tatsumaki first!\n"
}
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;

package ChatPollHandler;
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

package ChatMultipartPollHandler;
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

package ChatPostHandler;
use base qw(Tatsumaki::Handler);

sub post {
    my($self, $channel) = @_;
    my $v = $self->request->params;
    Encode::_utf8_on($v->{$_}) for keys %$v;
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish($v);
    $self->write({ success => 1 });
}

package main;
use File::Basename;

my $chat_re = '[\w\.\-]+';

my $app = Tatsumaki::Application->new([
    "/chat/($chat_re)/poll" => 'ChatPollHandler',
    "/chat/($chat_re)/mxhrpoll" => 'ChatMultipartPollHandler',
    "/chat/($chat_re)/post" => 'ChatPostHandler',
]);

$app->template_path(dirname(__FILE__) . "/templates");

# TODO this should be part of core
use Plack::Middleware::Static;
$app = Plack::Middleware::Static->wrap($app, path => sub { s{^/+$}{/index.html}; m{^/(?!chat/)} }, root => dirname(__FILE__));

use Tatsumaki::Middleware::BlockingFallback;
$app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

my @svc;

if (__FILE__ eq $0) {
    require Tatsumaki::Server;
    Tatsumaki::Server->new(port => 9999)->run($app);
} else {
    $app->{_svc} = \@svc; # HACK: refcount
    return $app;
}
