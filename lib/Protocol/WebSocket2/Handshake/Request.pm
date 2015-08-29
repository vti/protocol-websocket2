package Protocol::WebSocket2::Handshake::Request;

use strict;
use warnings;

use Carp qw(croak);
use MIME::Base64 ();
use URI;
use Scalar::Util qw(blessed);
use List::Util qw(first);
use Protocol::WebSocket2::Handshake::Response;
use Protocol::WebSocket2::Handshake::Request::hixie_75;
use Protocol::WebSocket2::Util
  qw(header_get header_get_lc dispatch_legacy is_legacy);

sub new {
    my $class = shift;
    my (%params) = @_;

    return dispatch_legacy(@_) if is_legacy($params{version});

    my $self = {};
    bless $self, $class;

    $self->{version} = $params{version} || 'rfc6455';

    $self->_init(%params);

    return $self;
}

sub _init {
    my $self = shift;
    my (%params) = @_;

    $self->{key} = $params{key} || $self->_generate_key;

    croak 'url required' unless $params{url};

    $self->{url} = $params{url};
    $self->{url} = URI->new($self->{url}) unless blessed $self->{url};

    croak 'url does not look like a websocket url'
      unless $self->{url}->scheme && $self->{url}->scheme =~ m/^wss?$/;

    my $resource = $self->{url}->path_query;
    $resource = '/' unless $resource =~ m{^/};
    $self->{resource} = $resource;

    my $host = $self->{url}->host_port;
    $host =~ s{:80$}{};

    $self->{method} = 'GET';

    $self->{headers} = [@{$params{headers} || []}];

    if (!@{$self->{headers}}) {
        push @{$self->{headers}}, 'Upgrade'    => 'WebSocket';
        push @{$self->{headers}}, 'Connection' => 'Upgrade';
        push @{$self->{headers}}, 'Host'       => $host;
        push @{$self->{headers}}, $self->_default_headers;
    }

    if (!header_get $self->{headers}, 'Host') {
        push @{$self->{headers}}, Host => $host;
    }

    return $self;
}

sub _default_headers {
    my $self = shift;

    return ('Sec-WebSocket-Key' => $self->{key}, 'Sec-WebSocket-Version' => 13);
}

sub version  { $_[0]->{version} }
sub method   { $_[0]->{method} }
sub url      { $_[0]->{url} }
sub resource { $_[0]->{resource} }
sub headers  { $_[0]->{headers} }
sub key      { $_[0]->{key} }

sub from_params {
    my $class = shift;
    my (%params) = @_;

    if ($params{method} && uc($params{method}) ne 'GET') {
        croak 'invalid method';
    }

    my $url = $class->_build_url_from_params(%params);

    my $headers = [@{$params{headers} || []}];

    croak 'Upgrade header missing or invalid'
      unless header_get_lc($headers, 'Upgrade') eq 'websocket';
    croak 'Connection header missing or invalid'
      unless first { lc($_) eq 'upgrade' } split /\s*,\s*/,
      header_get($headers, 'Connection');

    croak 'Sec-WebSocket-Key header missing'
      unless header_get $headers, 'Sec-WebSocket-Key';
    croak 'Sec-WebSocket-Version header missing or invalid'
      unless header_get($headers, 'Sec-WebSocket-Version') eq '13';

    my $key = header_get $headers, 'Sec-WebSocket-Key';
    croak 'Sec-WebSocket-Key required'
      unless $key;

    return $class->new(key => $key, url => $url, headers => $headers);
}

sub _build_url_from_params {
    my $self = shift;
    my (%params) = @_;

    my $url = $params{url};
    if (!$url) {
        croak 'Resource missing' unless $params{resource};

        my $headers = [@{$params{headers} || []}];

        croak 'Host header missing'
          unless my $host = header_get $headers, 'Host';

        $url = URI->new("ws://$host$params{resource}");
    }

    return $url;
}

sub from_http_request {
    my $class = shift;
    my ($req) = @_;

    my @headers =
      map { $_ => $req->headers->header($_) } $req->headers->header_field_names;

    my $url = $req->uri;
    if (!$url->scheme) {
        $url->scheme('ws');
        $url->host_port($req->headers->header('Host'));
    }

    return $class->from_params(
        key => ($req->headers->header('Sec-WebSocket-Key') // ''),
        method  => $req->method,
        url     => $url,
        headers => \@headers,
    );
}

sub from_psgi {
    my $class = shift;
    my ($env) = @_;

    my $resource = "$env->{SCRIPT_NAME}$env->{PATH_INFO}"
      . ($env->{QUERY_STRING} ? "?$env->{QUERY_STRING}" : "");

    my @header_names = grep { /^HTTP_/ } sort keys %$env;
    my @headers;
    foreach my $header_name (@header_names) {
        my $canonical = $header_name;
        $canonical =~ s{^HTTP_}{};
        $canonical =~ s{_}{-}g;
        push @headers, lc $canonical => $env->{$header_name};
    }

    return $class->from_params(
        method   => $env->{REQUEST_METHOD},
        resource => $resource,
        headers  => \@headers,
    );
}

sub to_params {
    my $self = shift;

    return (
        method   => $self->method,
        resource => $self->resource,
        headers  => [@{$self->{headers}}]
    );
}

sub to_http_request {
    my $self = shift;

    my $path_query = $self->url->path_query;
    $path_query = '/' . $path_query unless $path_query =~ m{^/};

    my $req = HTTP::Request->new($self->method, $path_query, $self->headers);
    $req->protocol('HTTP/1.1');

    return $req;
}

sub to_string {
    my $self = shift;

    return $self->to_http_request->as_string("\r\n");
}

sub new_response {
    my $self = shift;

    return Protocol::WebSocket2::Handshake::Response->new(
        key     => $self->{key},
        version => $self->{version}
    );
}

sub _generate_key {
    my $self = shift;

    my $key = '';
    $key .= chr(int(rand(256))) for 1 .. 16;

    $key = MIME::Base64::encode_base64($key);
    $key =~ s{\s+}{}g;

    return $key;
}

1;
