#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use AnyEvent::Socket;
use AnyEvent::Handle;

use HTTP::Parser;
use HTTP::Response;
use URI::ws;

use Protocol::WebSocket2::Handshake::Request;
use Protocol::WebSocket2::FrameBuffer;
use Protocol::WebSocket2::Frame;

my ($address) = @ARGV;
die 'Usage: <address>' unless $address;

my $url = URI->new($address);

my $cv = AnyEvent->condvar;

my $hdl;

AnyEvent::Socket::tcp_connect $url->host, $url->port, sub {
    my ($fh) = @_ or die $!;

    warn "Connected to server\n";

    $hdl = AnyEvent::Handle->new(fh => $fh);

    my $hs_req = Protocol::WebSocket2::Handshake::Request->new(url => $url);

    $hdl->push_write($hs_req->to_string);

    my $parser = HTTP::Parser->new(response => 1);
    my $frame_buffer = Protocol::WebSocket2::FrameBuffer->new;

    my $handshake_read;

    $hdl->on_read(
        sub {
            my $hdl = shift;

            my $chunk = $hdl->{rbuf};
            $hdl->{rbuf} = undef;

            if ($handshake_read) {
                $frame_buffer->append($chunk);

                while (my $frame = $frame_buffer->next_frame) {
                    if ($frame->is_close) {
                        warn "< EOF\n";

                        warn "Disconnect from server\n";

                        $hdl->destroy;

                        $cv->send;
                    }
                    else {
                        my $payload = $frame->payload;

                        warn "< $payload\n";

                        warn "> EOF\n";

                        my $frame = Protocol::WebSocket2::Frame->new(
                            masked  => 1,
                            type => 'close'
                        );

                        $hdl->push_write($frame->to_bytes);

                        last;
                    }
                }

                return;
            }

            my $status = $parser->add($chunk);

            if ($status == 0) {
                my $res = $parser->request;

                Protocol::WebSocket2::Handshake::Response->from_http_response(
                    $res, key => $hs_req->key);

                warn "Handshake done\n";
                $handshake_read++;

                my $payload = 'Hello';

                warn "> $payload\n";

                my $frame = Protocol::WebSocket2::Frame->new(
                    masked  => 1,
                    payload => $payload
                );

                $hdl->push_write($frame->to_bytes);
            }
        }
    );
};

$cv->wait;
