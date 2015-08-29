#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use AnyEvent::Socket;
use AnyEvent::Handle;

use Protocol::WebSocket2::Server;

my ($address) = @ARGV;
die 'Usage: <address>' unless $address;
my $url = URI->new($address);
die 'use ws(s):// scheme' unless $url->scheme && $url->scheme =~ /^wss?$/;
$url->host('0.0.0.0') if $url->host eq '*';

my $cv = AnyEvent->condvar;

my $hdl;

warn 'Listening on ' . $url->host . ':' . $url->port . "\n";
AnyEvent::Socket::tcp_server $url->host, $url->port, sub {
    my ($clsock, $host, $port) = @_;

    warn "Client connected\n";

    my $server = Protocol::WebSocket2::Server->new;

    $hdl = AnyEvent::Handle->new(
        fh => $clsock,
        $url->scheme eq 'wss'
        ? (
            tls     => 'accept',
            tls_ctx => {cert_file => dirname(__FILE__) . '/cert.pem'}
          )
        : ()
    );

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
