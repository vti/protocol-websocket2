use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::FrameBuffer';

subtest 'returns undef by default' => sub {
    my $fb = _build_frame_buffer();

    $fb->append;
    ok !defined $fb->next_frame;

    $fb->append('');
    ok !defined $fb->append;
};

subtest 'parses text frame' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "810548656c6c6f"));

    my $f = $fb->next_frame;

    is $f->payload, 'Hello';
    ok $f->is_text;
};

subtest 'parses several frames' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "810548656c6c6f") . pack('H*', "810548656c6c6f"));

    is $fb->next_frame->payload, 'Hello';
};

subtest 'parses masked frame' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "818537fa213d7f9f4d5158"));

    my $f = $fb->next_frame;

    is $f->payload, 'Hello';
    ok $f->masked;
    ok $f->is_text;
};

subtest 'parses fragments' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "010348656c"));
    ok !defined $fb->next_frame;

    $fb->append(pack('H*', "80026c6f"));

    is $fb->next_frame->payload, 'Hello';
};

subtest 'parses injected control frames' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "010348656c"));
    $fb->append(pack('H*', "890548656c6c6f"));
    $fb->append(pack('H*', "80026c6f"));

    is $fb->next_frame->opcode, 9;
    is $fb->next_frame->opcode, 1;
};

subtest 'throws when too many fragments' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "010348656c")) for 1 .. 129;
    eval { $fb->next_frame };
    ok $@;
};

subtest 'parses opcode' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(pack('H*', "890548656c6c6f"));

    is $fb->next_frame->opcode, 9;
};

sub _build_frame_buffer { Protocol::WebSocket2::FrameBuffer->new(@_) }

done_testing;
