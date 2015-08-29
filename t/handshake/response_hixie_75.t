use strict;
use warnings;

use Test::More;
use Test::Fatal;

use_ok 'Protocol::WebSocket2::Handshake::Response::hixie_75';

subtest 'default values' => sub {
    my $res =
      _res()->new(origin => 'http://localhost', location => 'ws://localhost');

    is $res->code,    101;
    is $res->message, 'WebSocket Protocol Handshake';

    is_deeply $res->headers,
      [
        'Upgrade'            => 'WebSocket',
        'Connection'         => 'Upgrade',
        'WebSocket-Origin'   => 'http://localhost',
        'WebSocket-Location' => 'ws://localhost',
      ];
};

subtest 'round' => sub {
    my $res = _res()->from_params(
        code    => 101,
        headers => [
            upgrade              => 'websocket',
            connection           => 'Upgrade',
            'WebSocket-Origin'   => 'http://localhost',
            'WebSocket-Location' => 'ws://localhost',
        ]
    );

    is_deeply { $res->to_params },
      {
        code    => 101,
        message => 'WebSocket Protocol Handshake',
        headers => [
            'upgrade'            => 'websocket',
            'connection'         => 'Upgrade',
            'WebSocket-Origin'   => 'http://localhost',
            'WebSocket-Location' => 'ws://localhost',
        ]
      };
};

subtest 'from http response' => sub {
    my $http_response = HTTP::Response->new(
        101,
        'WebSocket Protocol Handshake',
        [
            'Upgrade'            => 'WebSocket',
            'Connection'         => 'Upgrade',
            'WebSocket-Origin'   => 'http://localhost',
            'WebSocket-Location' => 'ws://localhost',
        ],
    );

    my $res = _res()->from_http_response($http_response);

    is $res->code,    101;
    is $res->message, 'WebSocket Protocol Handshake';
    is_deeply $res->headers,
      [
        'Connection'         => 'Upgrade',
        'Upgrade'            => 'WebSocket',
        'WebSocket-Location' => 'ws://localhost',
        'WebSocket-Origin'   => 'http://localhost',
      ];
};

sub _res { 'Protocol::WebSocket2::Handshake::Response::hixie_75' }

done_testing;
