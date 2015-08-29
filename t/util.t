use strict;
use warnings;

use Test::More;

use Protocol::WebSocket2::Util qw(header_get header_get_lc);

subtest 'empty when no header' => sub {
    is header_get([], 'foo'), '';
    is header_get([Ha => 'ha'], 'foo'), '';
};

subtest 'empty value when header empty' => sub {
    is header_get([Foo => ''], 'Foo'), '';
};

subtest 'value when header present' => sub {
    is header_get([Foo => 'bar'], 'Foo'), 'bar';
};

subtest 'value when header present case insensitive' => sub {
    is header_get([Foo => 'bar'], 'foo'), 'bar';
};

subtest 'lc value' => sub {
    is header_get_lc([Foo => 'Bar'], 'foo'), 'bar';
};

done_testing;
