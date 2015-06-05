use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::Frame';

subtest 'default values' => sub {
    my $f = _build_frame();

    is $f->to_bytes, pack('H*', "8100");
    is $f->payload,  '';
    is $f->opcode,   1;
    is $f->masked,   0;
    ok $f->is_text;
    ok $f->fin;
};

subtest 'builds text frame' => sub {
    my $f = _build_frame(payload => 'Hello');

    is $f->to_bytes, pack('H*', "810548656c6c6f");
    is $f->opcode,   1;
    is $f->masked,   0;
    ok $f->is_text;
};

subtest 'builds masked text frame' => sub {
    my $f = _build_frame(payload => 'Hello', masked => 1, mask => 1);

    is $f->to_bytes, pack('H*', "81850000000148656c6d6f");
    is $f->opcode,   1;
    is $f->masked,   1;
    ok $f->is_text;
};

subtest 'builds ping request' => sub {
    my $f = _build_frame(type => 'ping', payload => 'Hello');

    is $f->to_bytes => pack('H*', "890548656c6c6f");
    is $f->opcode, 9;
    ok $f->is_ping;
};

subtest 'builds pong response' => sub {
    my $f = _build_frame(type => 'pong', payload => 'Hello');

    is $f->to_bytes => pack('H*', "8a0548656c6c6f");
    is $f->opcode, 10;
    ok $f->is_pong;
};

subtest 'builds close' => sub {
    my $f = _build_frame(type => 'close');

    is $f->to_bytes, pack('H*', "8800");
    is $f->opcode, 8;
    ok $f->is_close;
};

subtest 'builds binary 256 bytes' => sub {
    my $f = _build_frame(type => 'binary', payload => pack('H*', '05' x 256));

    is $f->to_bytes, pack('H*', "827E0100" . ('05' x 256));
    is $f->opcode, 2;
    ok $f->is_binary;
};

subtest 'builds binary 64KiB' => sub {
    my $f = _build_frame(type => 'binary', payload => pack('H*', '05' x 65536));

    is $f->to_bytes, pack('H*', "827F0000000000010000" . ('05' x 65536));
    is $f->opcode, 2;
    ok $f->is_binary;
};

subtest 'builds continuation' => sub {
    my $f = _build_frame(type => 'continuation');

    is $f->to_bytes, pack('H*', '8000');
    is $f->opcode, 0;
    ok $f->is_continuation;
};

subtest 'constructor type values and is_$type are consistent' => sub {
    my @types = qw(continuation text binary ping pong close);
    foreach my $type (@types) {
        my $f = _build_frame(type => $type);
        foreach my $test_type (@types) {
            my $method = "is_$test_type";
            if ($type eq $test_type) {
                ok $f->$method, "type $type $method";
            }
            else {
                ok !$f->$method, "type $type not $method";
            }
        }
    }
};

subtest 'opcode accessor/mutator' => sub {
    my $f = _build_frame(payload => "Hello");

    is $f->opcode, 1;
    is $f->to_bytes, pack('H*', "810548656c6c6f");

    $f->opcode(2);
    is $f->opcode, 2;
    is $f->to_bytes, pack('H*', "820548656c6c6f");

    $f->opcode(0);
    is $f->opcode, 0;
    is $f->to_bytes, pack('H*', "800548656c6c6f");
};

subtest 'if both type and opcode are specified in new(), type wins' => sub {
    my $f = _build_frame(
        payload => 'Hello',
        type    => 'ping',
        opcode  => 2
    );

    is $f->opcode, 9;
    is $f->to_bytes, pack('H*', "890548656c6c6f");
};

sub _build_frame { Protocol::WebSocket2::Frame->new(@_) }

done_testing;
