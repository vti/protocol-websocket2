#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use URI;
use AnyEvent::Socket;
use AnyEvent::Handle;

use Protocol::WebSocket2::Client;

my ($address) = @ARGV;
die 'Usage: <address>' unless $address;

my $cv = AnyEvent->condvar;

my $hdl;

my $url = URI->new($address);
AnyEvent::Socket::tcp_connect $url->host, $url->port, sub {
    my ($fh) = @_ or die $!;

    warn "Connected to server\n";

    my $client = Protocol::WebSocket2::Client->new(url => $url);

    $hdl = AnyEvent::Handle->new(fh => $fh);
    $hdl->on_read(
        sub {
            my $hdl = shift;

            my $chunk = $hdl->{rbuf};
            $hdl->{rbuf} = undef;

            $client->parse($chunk);
        }
    );

    $client->write_cb(sub { $hdl->push_write($_[0]) });

    $client->on_handshake(
        sub {
            warn "Handshake done\n";

            my $payload = 'Hello';

            warn "> $payload\n";

            $client->send_message($payload);
        }
    );
    $client->on_message(
        sub {
            my ($payload) = @_;

            warn "< $payload\n";

            warn "> EOF\n";
            $client->send_frame(type => 'close');
        }
    );
    $client->on_close(
        sub {
            warn "< EOF\n";

            warn "Disconnect from server\n";

            $hdl->destroy;

            $cv->send;
        }
    );

    $client->handshake;
};

$cv->wait;
