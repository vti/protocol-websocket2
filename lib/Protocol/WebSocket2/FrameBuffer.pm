package Protocol::WebSocket2::FrameBuffer;

use strict;
use warnings;

use Config;
use Protocol::WebSocket2::Frame;
use Protocol::WebSocket2::Util qw(dispatch_legacy is_legacy);
use Protocol::WebSocket2::FrameBuffer::hixie_75;

sub new {
    my $class = shift;
    my (%params) = @_;

    return dispatch_legacy(@_) if is_legacy($params{version});

    my $self = {};
    bless $self, $class;

    $self->{fragments} = [];

    $self->{max_fragments_amount} ||= 128;
    $self->{max_payload_size}     ||= 65536;

    $self->{buffer} = '';

    return $self;
}

sub append {
    my $self = shift;

    return unless defined $_[0];

    $self->{buffer} .= $_[0];

    return $self;
}

sub next_frame {
    my $self = shift;

    return unless length $self->{buffer} >= 2;

    my $fin;
    my $rsv;
    my $masked;

    while (length $self->{buffer}) {
        my $hdr = substr($self->{buffer}, 0, 1);

        my @bits = split //, unpack("B*", $hdr);

        $fin = $bits[0];
        $rsv = [@bits[1 .. 3]];

        my $opcode = unpack('C', $hdr) & 0b00001111;

        my $offset = 1;    # FIN,RSV[1-3],OPCODE

        my $payload_len = unpack 'C', substr($self->{buffer}, 1, 1);

        my $masked = ($payload_len & 0b10000000) >> 7;

        $offset += 1;      # + MASKED,PAYLOAD_LEN

        $payload_len = $payload_len & 0b01111111;
        if ($payload_len == 126) {
            return unless length($self->{buffer}) >= $offset + 2;

            $payload_len = unpack 'n', substr($self->{buffer}, $offset, 2);

            $offset += 2;
        }
        elsif ($payload_len > 126) {
            return unless length($self->{buffer}) >= $offset + 4;

            my $bits = join '', map { unpack 'B*', $_ } split //,
              substr($self->{buffer}, $offset, 8);

            # Most significant bit must be 0.
            # And here is a crazy way of doing it %)
            $bits =~ s{^.}{0};

            # Can we handle 64bit numbers?
            if ($Config{ivsize} <= 4 || $Config{longsize} < 8 || $] < 5.010) {
                $bits = substr($bits, 32);
                $payload_len = unpack 'N', pack 'B*', $bits;
            }
            else {
                $payload_len = unpack 'Q>', pack 'B*', $bits;
            }

            $offset += 8;
        }

        if ($payload_len > $self->{max_payload_size}) {
            $self->{buffer} = '';
            die "Payload is too big. "
              . "Deny big message ($payload_len) "
              . "or increase max_payload_size ($self->{max_payload_size})";
        }

        my $mask;
        if ($masked) {
            return unless length($self->{buffer}) >= $offset + 4;

            $mask = substr($self->{buffer}, $offset, 4);
            $offset += 4;
        }

        return if length($self->{buffer}) < $offset + $payload_len;

        my $payload = substr($self->{buffer}, $offset, $payload_len);

        if ($masked) {
            $payload = $self->_mask($payload, $mask);
        }

        substr($self->{buffer}, 0, $offset + $payload_len, '');

        # Injected control frame
        if (@{$self->{fragments}} && $opcode & 0b1000) {
            return Protocol::WebSocket2::Frame->new(
                opcode  => $opcode,
                fin     => $fin,
                rsv     => $rsv,
                masked  => $masked,
                payload => $payload
            );
        }

        if ($fin) {
            if (@{$self->{fragments}}) {
                $opcode = shift @{$self->{fragments}};
            }
            $payload = join '', @{$self->{fragments}}, $payload;
            $self->{fragments} = [];

            return Protocol::WebSocket2::Frame->new(
                opcode  => $opcode,
                fin     => $fin,
                rsv     => $rsv,
                masked  => $masked,
                payload => $payload
            );
        }
        else {

            # Remember first fragment opcode
            if (!@{$self->{fragments}}) {
                push @{$self->{fragments}}, $opcode;
            }

            push @{$self->{fragments}}, $payload;

            die "Too many fragments"
              if @{$self->{fragments}} > $self->{max_fragments_amount};
        }
    }

    return;
}

sub size {
    my $self = shift;

    return length $self->{buffer};
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
