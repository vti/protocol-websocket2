package Protocol::WebSocket2::Handshake::Request;

use strict;
use warnings;

use MIME::Base64 ();
use List::Util qw(first);
use Protocol::WebSocket2::Handshake::Response;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{key}  = $params{key};
    $self->{host} = $params{host};

    $self->{method}   = $params{method}   || 'GET';
    $self->{resource} = $params{resource} || '/';
    $self->{headers} = [@{$params{headers} || []}];

    return $self;
}

sub from_params {
    my $self = shift;
    my (%params) = @_;

    $self->{headers} = [@{$params{headers} || []}];

    my %headers;
    while (my ($key, $value) = splice(@{$params{headers}}, 0, 2)) {
        $headers{lc($key)} = $value if first { lc($key) eq $_ } qw/
          host
          upgrade
          connection
          sec-websocket-key
          sec-websocket-version
          /;
    }

    return unless $headers{upgrade} && lc($headers{upgrade}) eq 'websocket';
    return
      unless $headers{connection} && first { lc($_) eq 'upgrade' }
    split /\s*,\s*/, $headers{connection};

    return unless $headers{'host'};
    return unless $headers{'sec-websocket-key'};
    return unless $headers{'sec-websocket-version'};

    $self->{key} = $headers{'sec-websocket-key'};

    return $self;
}

sub from_http_request {
    my $self = shift;
    my ($req) = @_;

    my @headers =
      map { $_ => $req->headers->header($_) } $req->headers->header_field_names;

    return $self->from_params(
        method   => $req->method,
        resource => $req->uri->path,
        headers  => \@headers,
        body     => $req->content
    );
}

sub from_psgi {
    my $self = shift;
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

    return $self->from_params(
        method   => $env->{REQUEST_METHOD},
        resource => $resource,
        headers  => \@headers,
    );
}

sub to_params {
    my $self = shift;

    my $key = $self->{key};

    if (!$key) {
        $key = '';
        $key .= chr(int(rand(256))) for 1 .. 16;

        $key = MIME::Base64::encode_base64($key);
        $key =~ s{\s+}{}g;

        $self->{key} = $key;
    }

    push @{$self->{headers}}, 'Upgrade' => 'WebSocket'
      unless first { lc($_) eq 'upgrade' } @{$self->{headers}};
    push @{$self->{headers}}, 'Connection' => 'Upgrade'
      unless first { lc($_) eq 'connection' } @{$self->{headers}};
    push @{$self->{headers}}, 'Host' => $self->{host}
      unless first { lc($_) eq 'host' } @{$self->{headers}};
    push @{$self->{headers}}, 'Sec-WebSocket-Key' => $key
      unless first { lc($_) eq 'sec-websocket-key' } @{$self->{headers}};
    push @{$self->{headers}}, 'Sec-WebSocket-Version' => 13
      unless first { lc($_) eq 'sec-websocket-version' } @{$self->{headers}};

    return (
        method   => $self->{method},
        resource => $self->{resource},
        headers  => [@{$self->{headers}}]
    );
}

sub new_response {
    my $self = shift;

    return Protocol::WebSocket2::Handshake::Response->new(key => $self->{key});
}

1;
