package Protocol::WebSocket2::Handshake::Request::hixie_75;

use strict;
use warnings;

use base 'Protocol::WebSocket2::Handshake::Request';

use Carp qw(croak);
use Protocol::WebSocket2::Util qw(header_get header_get_lc);
use Protocol::WebSocket2::Handshake::Response;
use Protocol::WebSocket2::Handshake::Response::hixie_75;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{version} = $params{version} || 'hixie_75';

    $self->_init(%params);

    return $self;
}

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    if (!header_get $self->{headers}, 'Origin') {
        my $origin = $self->{url}->clone;
        $origin->scheme('http');
        push @{$self->{headers}}, Origin => $origin;
    }

    return $self;
}

sub _default_headers { () }

sub from_params {
    my $class = shift;
    my (%params) = @_;

    if ($params{method} && uc($params{method}) ne 'GET') {
        croak 'invalid method';
    }

    my $url = $class->_build_url_from_params(%params);

    my $headers = [@{$params{headers} || []}];

    croak 'Connection header missing or invalid'
      unless header_get_lc($headers, 'Connection') eq 'upgrade';
    croak 'Upgrade header missing or invalid'
      unless header_get_lc($headers, 'Upgrade') eq 'websocket';
    croak 'Host header missing'
      unless defined header_get $headers, 'Host';
    croak 'Origin header missing'
      unless defined header_get $headers, 'Origin';

    return $class->new(url => $url, headers => $headers);
}

sub new_response {
    my $self = shift;

    return Protocol::WebSocket2::Handshake::Response->new(
        version => $self->{version});
}

1;
