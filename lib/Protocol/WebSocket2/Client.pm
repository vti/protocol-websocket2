package Protocol::WebSocket2::Client;

use strict;
use warnings;

use base 'Protocol::WebSocket2::PeerBase';

use Carp qw(croak);
use HTTP::Parser;
use Protocol::WebSocket2::Handshake::Request;
use Protocol::WebSocket2::Handshake::Response;
use Protocol::WebSocket2::Frame;

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    croak 'url required' unless $params{url};
    $self->{url} = $params{url};

    return $self;
}

sub handshake {
    my $self = shift;

    my $req = $self->{req} =
      Protocol::WebSocket2::Handshake::Request->new(url => $self->{url});

    $self->{write_cb}->($req->to_string);

    return $self;
}

sub _finalize_handshake {
    my $self = shift;
    my ($res) = @_;

    Protocol::WebSocket2::Handshake::Response->from_http_response($res,
        key => $self->{req}->key);
}

sub _build_parser {
    my $self = shift;

    return $self->SUPER::_build_parser(response => 1, @_);
}

sub _build_frame {
    my $self = shift;

    return $self->SUPER::_build_frame(masked => 1, @_);
}

1;
