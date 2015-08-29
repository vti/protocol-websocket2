package Protocol::WebSocket2::Handshake::Response::hixie_75;

use strict;
use warnings;

use base 'Protocol::WebSocket2::Handshake::Response';

use Carp qw(croak);
use Protocol::WebSocket2::Util qw(header_get header_get_lc);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{version} = 'hixie-75';

    $self->{code}    = 101;
    $self->{message} = 'WebSocket Protocol Handshake';

    $self->{headers} = [@{$params{headers} || []}];

    if (!@{$self->{headers}}) {
        $self->{headers} = [
            'Upgrade'    => 'WebSocket',
            'Connection' => 'Upgrade',
            'WebSocket-Origin' => $params{origin},
            'WebSocket-Location' => $params{location},
        ];
    }

    return $self;
}

sub from_params {
    my $class = shift;
    my (%params) = @_;

    if ($params{code} && $params{code} ne '101') {
        croak 'Invalid code';
    }

    my $headers = [@{$params{headers} || []}];

    croak 'Upgrade header missing or invalid'
      unless header_get_lc($headers, 'Upgrade') eq 'websocket';
    croak 'Connection header missing or invalid'
      unless header_get_lc($headers, 'Connection') eq 'upgrade';
    croak 'WebSocket-Origin header missing or invalid'
      unless my $origin = header_get($headers, 'WebSocket-Origin');
    croak 'WebSocket-Location header missing or invalid'
      unless my $location = header_get($headers, 'WebSocket-Location');

    return $class->new(
        headers  => $headers,
        origin   => $origin,
        location => $location
    );
}

sub from_http_response {
    my $class = shift;
    my ($res) = @_;

    my @headers =
      map { $_ => $res->headers->header($_) } $res->headers->header_field_names;

    return $class->from_params(
        code    => $res->code,
        message => $res->message,
        headers => \@headers,
    );
}

1;
