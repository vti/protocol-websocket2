package Protocol::WebSocket2::Frame;

use strict;
use warnings;

use Config;

use constant MAX_RAND_INT       => 2**32;
use constant MATH_RANDOM_SECURE => eval "require Math::Random::Secure;";

our %TYPES = (
    continuation => 0x00,
    text         => 0x01,
    binary       => 0x02,
    ping         => 0x09,
    pong         => 0x0a,
    close        => 0x08
);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{payload} = $params{payload} // '';
    $self->{mask}    = $params{mask}    // 0;
    $self->{masked}  = $params{masked}  // 0;
    $self->{opcode}  = $params{opcode}  // 1;

    if (defined($params{type}) && exists $TYPES{$params{type}}) {
        $self->{opcode} = $TYPES{$params{type}};
    }

    return $self;
}

sub fin {
    @_ > 1 ? $_[0]->{fin} =
        $_[1]
      : defined($_[0]->{fin}) ? $_[0]->{fin}
      :                         1;
}
sub rsv { @_ > 1 ? $_[0]->{rsv} = $_[1] : $_[0]->{rsv} }

sub opcode {
    @_ > 1 ? $_[0]->{opcode} =
        $_[1]
      : defined($_[0]->{opcode}) ? $_[0]->{opcode}
      :                            1;
}
sub masked { @_ > 1 ? $_[0]->{masked} = $_[1] : $_[0]->{masked} }

sub is_ping         { $_[0]->opcode == 9 }
sub is_pong         { $_[0]->opcode == 10 }
sub is_close        { $_[0]->opcode == 8 }
sub is_continuation { $_[0]->opcode == 0 }
sub is_text         { $_[0]->opcode == 1 }
sub is_binary       { $_[0]->opcode == 2 }

sub payload { @_ > 1 ? $_[0]->{payload} = $_[1] : $_[0]->{payload} }

sub to_bytes {
    my $self = shift;

    my $opcode = $self->opcode;

    my $frame = '';

    $frame .= pack 'C', ($opcode + ($self->fin ? 128 : 0));

    my $payload_len = length($self->{payload});
    if ($payload_len <= 125) {
        $payload_len |= 0b10000000 if $self->masked;
        $frame .= pack 'C', $payload_len;
    }
    elsif ($payload_len <= 0xffff) {
        $frame .= pack 'C', 126 + ($self->masked ? 128 : 0);
        $frame .= pack 'n', $payload_len;
    }
    else {
        $frame .= pack 'C', 127 + ($self->masked ? 128 : 0);

        # Shifting by an amount >= to the system wordsize is undefined
        $frame .= pack 'N', $Config{ivsize} <= 4 ? 0 : $payload_len >> 32;
        $frame .= pack 'N', ($payload_len & 0xffffffff);
    }

    if ($self->masked) {
        my $mask = $self->{mask}
          || (
            MATH_RANDOM_SECURE
            ? Math::Random::Secure::irand(MAX_RAND_INT)
            : int(rand(MAX_RAND_INT))
          );

        $mask = pack 'N', $mask;

        $frame .= $mask;
        $frame .= $self->_mask($self->{payload}, $mask);
    }
    else {
        $frame .= $self->{payload};
    }

    return $frame;
}

sub _mask {
    my $self = shift;
    my ($payload, $mask) = @_;

    $mask = $mask x (int(length($payload) / 4) + 1);
    $mask = substr($mask, 0, length($payload));
    $payload = "$payload" ^ $mask;

    return $payload;
}

1;
__END__
