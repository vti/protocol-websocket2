package Protocol::WebSocket2::Handshake::Response;

use strict;
use warnings;

use Carp qw(croak);
use Digest::SHA  ();
use MIME::Base64 ();
use HTTP::Response;
use Protocol::WebSocket2::Util
  qw(header_get header_get_lc dispatch_legacy is_legacy);

sub new {
    my $class = shift;
    my (%params) = @_;

    return dispatch_legacy(@_) if is_legacy($params{version});

    my $self = {};
    bless $self, $class;

    $self->{version} = $params{version} || 'rfc6455';
    $self->{key}     = $params{key}     || croak 'request key is required';

    $self->{code}    = 101;
    $self->{message} = 'Switching Protocols';

    $self->{headers} = [@{$params{headers} || []}];

    if (!@{$self->{headers}}) {
        $self->{headers} = [
            'Upgrade'              => 'WebSocket',
            'Connection'           => 'Upgrade',
            'Sec-WebSocket-Accept' => $self->_generate_accept($self->{key}),
        ];
    }

    return $self;
}

sub version { $_[0]->{version} }
sub code    { $_[0]->{code} }
sub message { $_[0]->{message} }
sub headers { $_[0]->{headers} }

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

    croak 'request key required' unless $params{key};
    croak 'Sec-WebSocket-Accept header missing or invalid'
      unless header_get($headers, 'Sec-WebSocket-Accept') eq
      $class->_generate_accept($params{key});

    return $class->new(key => $params{key}, headers => $headers);
}

sub to_params {
    my $self = shift;

    return (
        code    => $self->code,
        message => $self->message,
        headers => $self->headers
    );
}

sub to_http_response {
    my $self = shift;

    return HTTP::Response->new($self->code, $self->message, $self->headers);
}

sub from_http_response {
    my $class = shift;
    my ($res, %params) = @_;

    croak 'request key required' unless $params{key};

    my @headers =
      map { $_ => $res->headers->header($_) } $res->headers->header_field_names;

    return $class->from_params(
        key => $params{key},
        code => $res->code,
        message  => $res->message,
        headers => \@headers,
    );
}

sub to_psgi {
    my $self = shift;

    return [$self->code, $self->headers, []];
}

sub to_string {
    my $self = shift;

    my $res = $self->to_http_response;
    $res->protocol('HTTP/1.1');

    return $res->as_string("\r\n");
}

sub _generate_accept {
    my $self = shift;
    my ($key) = @_;

    my $accept = $key;
    $accept .= '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';    # WTF
    $accept = Digest::SHA::sha1($accept);
    $accept = MIME::Base64::encode_base64($accept);
    $accept =~ s{\s+}{}g;

    return $accept;
}

1;
