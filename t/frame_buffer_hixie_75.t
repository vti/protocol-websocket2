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

subtest 'extracts empty text' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(join '', chr(0x00), chr(0xff));
    my $f = $fb->next_frame;

    is $f->payload, '';
};

subtest 'extracts text' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(join '', chr(0x00), 'hello', chr(0xff));
    my $f = $fb->next_frame;

    is $f->payload, 'hello';
};

subtest 'removes extracted frame' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(
        join '',   chr(0x00), 'hello', chr(0xff),
        chr(0x00), 'there',   chr(0xff)
    );

    is $fb->next_frame->payload, 'hello';
    is $fb->next_frame->payload, 'there';
    ok !defined $fb->next_frame;
};

subtest 'glues data between calls' => sub {
    my $fb = _build_frame_buffer();

    $fb->append(join '', chr(0x00), 'hell');
    ok !defined $fb->next_frame;

    $fb->append(join '', 'o', chr(0xff));
    is $fb->next_frame->payload, 'hello';
};

subtest 'ignores unexpected data' => sub {
    my $fb = _build_frame_buffer();

    $fb->append('foobar');
    ok !defined $fb->next_frame;

    is $fb->size, 0;
};

subtest 'ignores garbage in front' => sub {
    my $fb = _build_frame_buffer();

    $fb->append("foobar\x00hello\xff");
    is $fb->next_frame->payload, 'hello';

    is $fb->size, 0;
};

sub _build_frame_buffer {
    Protocol::WebSocket2::FrameBuffer->new(version => 'hixie-75', @_);
}

done_testing;
