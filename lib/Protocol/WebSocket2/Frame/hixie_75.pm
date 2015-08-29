package Protocol::WebSocket2::Frame::hixie_75;

use strict;
use warnings;

use base 'Protocol::WebSocket2::Frame';

use Carp qw(croak);

our %TYPES = (
    text  => 1,
    close => 2
);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{payload} = $params{payload} // '';
    $self->{type}    = $params{type}    // 'text';

    croak 'unknown type' unless exists $TYPES{$self->{type}};

    return $self;
}

sub fin { 0 }
sub rsv { 0 }

sub opcode { 0x01 }
sub masked { 0 }

sub is_ping         { $_[0]->opcode == 9 }
sub is_pong         { $_[0]->opcode == 10 }
sub is_close        { $_[0]->opcode == 8 }
sub is_continuation { $_[0]->opcode == 0 }
sub is_text         { $_[0]->opcode == 1 }
sub is_binary       { $_[0]->opcode == 2 }

sub payload { @_ > 1 ? $_[0]->{payload} = $_[1] : $_[0]->{payload} }

sub to_bytes {
    my $self = shift;

    return "\x00" . $self->{payload} . "\xff";
}

1;
