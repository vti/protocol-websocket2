#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use AnyEvent::Socket;
use AnyEvent::Handle;

use HTTP::Parser;
use HTTP::Response;

use Protocol::WebSocket2::Handshake::Request;
use Protocol::WebSocket2::FrameBuffer;
use Protocol::WebSocket2::Frame;

my $cv = AnyEvent->condvar;

my $hdl;

AnyEvent::Socket::tcp_server undef, 3000, sub {
    my ($clsock, $host, $port) = @_;

    warn "Client connected\n";

    $hdl = AnyEvent::Handle->new(fh => $clsock);

    my $parser = HTTP::Parser->new(request => 1);

    my $frame_buffer = Protocol::WebSocket2::FrameBuffer->new;

    my $handshake_written;
    $hdl->on_eof(sub {});

    $hdl->on_read(
        sub {
            my $hdl = shift;

            my $chunk = $hdl->{rbuf};
            $hdl->{rbuf} = undef;

            if ($handshake_written) {
                $frame_buffer->append($chunk);

                while (my $frame = $frame_buffer->next_frame) {
                    if ($frame->is_close) {
                        warn "< EOF\n";

                        warn "> EOF\n";
                        my $frame = Protocol::WebSocket2::Frame->new(type => 'close');

                        $hdl->push_write($frame->to_bytes);
                        $hdl->on_eof(
                            sub {
                                warn "Close client connection\n";

                                $hdl->destroy;
                            }
                        );
                    }
                    else {
                        my $payload = $frame->payload;

                        warn "> $payload\n";

                        my $frame = Protocol::WebSocket2::Frame->new(payload => $payload);

                        warn "< $payload\n";

                        $hdl->push_write($frame->to_bytes);
                    }
                }

                return;
            }

            my $status = $parser->add($chunk);

            if ($status == 0) {
                my $req = $parser->request;

                my $hs_req = Protocol::WebSocket2::Handshake::Request->from_http_request($req);

                $hdl->push_write($hs_req->new_response->to_string);

                warn "Handshake done\n";
                $handshake_written++;
            }
        }
    );
};

$cv->wait;
