package Protocol::WebSocket2::FrameBuffer::hixie_75;

use strict;
use warnings;

use base 'Protocol::WebSocket2::FrameBuffer';

use Protocol::WebSocket2::Frame::hixie_75;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{buffer} = '';

    return $self;
}

sub next_frame {
    my $self = shift;

    return unless length $self->{buffer} > 1;

    my $start = index $self->{buffer}, chr(0x00);
    if ($start == -1) {
        $self->{buffer} = '';
        return;
    }

    substr $self->{buffer}, 0, $start, '';

    my $eof = index $self->{buffer}, chr(0xff);
    return if $eof == -1;

    my $payload = substr $self->{buffer}, 1, $eof - 1, '';
    substr $self->{buffer}, 0, 2, '';

    return Protocol::WebSocket2::Frame::hixie_75->new(payload => $payload);

    return;
}

1;
