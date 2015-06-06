use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::Handshake::Response';

subtest 'default values' => sub {
    my $res = _build_res(key => uc 'k' x 16);

    is_deeply { $res->to_params },
      {
        code    => 101,
        message => 'Switching Protocols',
        headers => [
            'Upgrade'              => 'WebSocket',
            'Connection'           => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
      };
};

subtest 'from params' => sub {
    my $res = _build_res(key => uc 'k' x 16);

    ok $res->from_params(
        code    => 101,
        headers => [
            upgrade                => 'websocket',
            connection             => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
    );
};

subtest 'not valid code' => sub {
    my $res = _build_res(key => uc 'k' x 16);

    ok !$res->from_params(code => 404);
};

subtest 'not accept invalid accept' => sub {
    my $res = _build_res(key => 'foo');

    ok !$res->from_params(
        headers => [
            upgrade                => 'websocket',
            connection             => 'Upgrade',
            'Sec-WebSocket-Accept' => 'foobar',
        ]
    );
};

subtest 'round' => sub {
    my $res = _build_res(key => uc 'k' x 16);

    ok $res->from_params(
        code    => 101,
        headers => [
            upgrade                => 'websocket',
            connection             => 'keep-alive, Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
    );

    is_deeply { $res->to_params },
      {
        code    => 101,
        message => 'Switching Protocols',
        headers => [
            'upgrade'              => 'websocket',
            'connection'           => 'keep-alive, Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
      };
};

sub _build_res { Protocol::WebSocket2::Handshake::Response->new(@_) }

done_testing;
