package Protocol::WebSocket2::Handshake::Response;

use strict;
use warnings;

use Carp qw(croak);
use Digest::SHA  ();
use MIME::Base64 ();
use List::Util qw(first);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{key} = $params{key} || croak 'request key is required';

    $self->{code}    = $params{code}    || 101;
    $self->{message} = $params{message} || 'Switching Protocols';
    $self->{headers} = [@{$params{headers} || []}];

    return $self;
}

sub from_params {
    my $self = shift;
    my (%params) = @_;

    return unless $params{code} && $params{code} eq 101;

    $self->{headers} = [@{$params{headers} || []}];

    my %headers;
    while (my ($key, $value) = splice(@{$params{headers}}, 0, 2)) {
        $headers{lc($key)} = $value if first { lc($key) eq $_ } qw/
          upgrade
          connection
          sec-websocket-accept
          /;
    }

    return unless $headers{upgrade} && lc($headers{upgrade}) eq 'websocket';
    return
      unless $headers{connection} && first { lc($_) eq 'upgrade' }
    split /\s*,\s*/, $headers{connection};

    return unless my $accept = $headers{'sec-websocket-accept'};

    return unless $self->_generate_accept($self->{key}) eq $accept;

    return $self;
}

sub to_params {
    my $self = shift;

    my $key = $self->_generate_accept($self->{key});

    push @{$self->{headers}}, 'Upgrade' => 'WebSocket'
      unless first { lc($_) eq 'upgrade' } @{$self->{headers}};
    push @{$self->{headers}}, 'Connection' => 'Upgrade'
      unless first { lc($_) eq 'connection' } @{$self->{headers}};
    push @{$self->{headers}}, 'Sec-WebSocket-Accept' => $key
      unless first { lc($_) eq 'sec-websocket-accept' } @{$self->{headers}};

    return (
        code    => $self->{code},
        message => $self->{message},
        headers => [@{$self->{headers}}]
    );
}

sub to_http_response {
    my $self = shift;

    my %params = $self->to_params;

    return
      HTTP::Response->new($params{code}, $params{message},
        $params{headers});
}

sub to_psgi {
    my $self = shift;

    my %params = $self->to_params;

    return [$params{code}, $params{headers}, []];
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
