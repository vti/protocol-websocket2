use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::Frame';

subtest 'default values' => sub {
    my $f = _build_frame();

    is $f->to_bytes, "\x00\xff";
    is $f->payload,  '';
};

subtest 'with payload' => sub {
    my $f = _build_frame(payload => 'foobar');

    is $f->to_bytes, "\x00foobar\xff";
    is $f->payload,  'foobar';
};

sub _build_frame { Protocol::WebSocket2::Frame->new(version => 'hixie-75', @_) }

done_testing;
