#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use AnyEvent::Socket;
use AnyEvent::Handle;

use Protocol::WebSocket2::Server;

my $cv = AnyEvent->condvar;

my $hdl;

AnyEvent::Socket::tcp_server undef, 3000, sub {
    my ($clsock, $host, $port) = @_;

    warn "Client connected\n";

    my $server = Protocol::WebSocket2::Server->new;

    $hdl = AnyEvent::Handle->new(fh => $clsock);

    $hdl->on_eof(sub { warn "Client disconnected\n" });

    $hdl->on_read(
        sub {
            my $hdl = shift;

            my $chunk = $hdl->{rbuf};
            $hdl->{rbuf} = undef;

            $server->parse($chunk);
        }
    );

    $server->write_cb(sub { $hdl->push_write($_[0]) });

    $server->on_handshake(sub { warn "Handshake done\n" });

    $server->on_message(
        sub {
            my ($payload) = @_;

            warn "< $payload\n";

            warn "> $payload\n";

            $server->send_message($payload);
        }
    );
    $server->on_close(
        sub {
            warn "< EOF\n";

            warn "> EOF\n";
            $server->send_frame(type => 'close');
        }
    );
};

$cv->wait;
