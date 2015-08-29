package Protocol::WebSocket2::Server;

use strict;
use warnings;

use base 'Protocol::WebSocket2::PeerBase';

use Carp qw(croak);
use Protocol::WebSocket2::Handshake::Request;

sub _finalize_handshake {
    my $self = shift;
    my ($req) = @_;

    my $hs_req =
      Protocol::WebSocket2::Handshake::Request->from_http_request($req);

    $self->{write_cb}->($hs_req->new_response->to_string);
}

1;
