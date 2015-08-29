package Protocol::WebSocket2::PeerBase;

use strict;
use warnings;

use Carp qw(croak);
use HTTP::Parser;
use Protocol::WebSocket2::Handshake::Request;
use Protocol::WebSocket2::FrameBuffer;
use Protocol::WebSocket2::Frame;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{parser}       = $self->_build_parser;
    $self->{frame_buffer} = Protocol::WebSocket2::FrameBuffer->new;

    $self->{on_handshake} = $params{on_handshake} || sub { };
    $self->{on_message}   = $params{on_message}   || sub { };
    $self->{on_close}     = $params{on_close}     || sub { };

    $self->{write_cb} = $params{write_cb} || sub { };

    return $self;
}

sub on_handshake { $_[0]->{on_handshake} = $_[1] }
sub on_message   { $_[0]->{on_message}   = $_[1] }
sub on_close     { $_[0]->{on_close}     = $_[1] }

sub write_cb { $_[0]->{write_cb} = $_[1] }

sub parse {
    my $self = shift;
    my ($chunk) = @_;

    if ($self->{handshake_done}) {
        my $frame_buffer = $self->{frame_buffer};

        $frame_buffer->append($chunk);

        while (my $frame = $frame_buffer->next_frame) {
            if ($frame->is_close) {
                $self->{on_close}->();
                last;
            }
            else {
                $self->{on_message}->($frame->payload);
            }
        }
    }
    else {
        my $status = $self->{parser}->add($chunk);

        if ($status == 0) {
            my $object = $self->{parser}->object;

            $self->_finalize_handshake($object);

            $self->{handshake_done}++;

            $self->{on_handshake}->();
        }
    }
}

sub send_message {
    my $self = shift;
    my ($message) = @_;

    my $frame = $self->_build_frame(payload => $message);

    $self->{write_cb}->($frame->to_bytes);
}

sub send_frame {
    my $self = shift;
    my (%params) = @_;

    my $frame = $self->_build_frame(%params);

    $self->{write_cb}->($frame->to_bytes);
}

sub _build_parser {
    my $self = shift;

    return HTTP::Parser->new(@_);
}

sub _build_frame {
    my $self = shift;

    return Protocol::WebSocket2::Frame->new(@_);
}

1;
