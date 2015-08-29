#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);

BEGIN { unshift @INC, dirname(__FILE__) . '/../lib' }

use AnyEvent::Handle;

use Protocol::WebSocket2::Handshake::Request;
use Protocol::WebSocket2::FrameBuffer;
use Protocol::WebSocket2::Frame;

sub {
    my $env = shift;

    my $hs_req = Protocol::WebSocket2::Handshake::Request->new->from_psgi($env);
    return [500, [], []] unless $hs_req;

    my $hdl = AnyEvent::Handle->new(fh => $env->{'psgix.io'});

    my $frame_buffer = Protocol::WebSocket2::FrameBuffer->new;

    return sub {
        my $respond = shift;

        my $res = $hs_req->new_response->to_psgi;

        $respond->($res->[0], $res->[1]);

        $hdl->on_read(
            sub {
                my $hdl = shift;

                my $chunk = $hdl->{rbuf};
                $hdl->{rbuf} = undef;

                if ($handshake_written) {
                    $frame_buffer->append($chunk);

                    while (my $frame = $frame_buffer->next_frame) {
                        my $payload = $frame->payload;

                        my $frame =
                          Protocol::WebSocket2::Frame->new(payload => $payload);

                        $hdl->push_write($frame->to_bytes);
                    }

                    return;
                }

                $hdl->push_write('HTTP/1.1 ' . $res->as_string);

                $handshake_written++;
            }
        );
      }
  }
