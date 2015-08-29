use strict;
use warnings;

use Test::More;
use Test::Fatal;

use_ok 'Protocol::WebSocket2::Handshake::Response';

subtest 'default values' => sub {
    my $res = _res()->new(key => uc 'k' x 16);

    is $res->code,    101;
    is $res->message, 'Switching Protocols';

    is_deeply $res->headers,
      [
        'Upgrade'              => 'WebSocket',
        'Connection'           => 'Upgrade',
        'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
      ];
};

subtest 'not accept invalid accept' => sub {
    my $res = _res();

    like exception {
        $res->from_params(
            key     => '123',
            headers => [
                upgrade                => 'websocket',
                connection             => 'Upgrade',
                'Sec-WebSocket-Accept' => 'foobar',
            ]
          )
    }, qr/Accept header missing or invalid/;
};

subtest 'round' => sub {
    my $res = _res()->from_params(
        key     => uc 'k' x 16,
        code    => 101,
        headers => [
            upgrade                => 'websocket',
            connection             => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
    );

    is_deeply { $res->to_params },
      {
        code    => 101,
        message => 'Switching Protocols',
        headers => [
            'upgrade'              => 'websocket',
            'connection'           => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
        ]
      };
};

subtest 'builds http response' => sub {
    my $res = _res()->new(key => uc 'k' x 16);

    my $http_res = $res->to_http_response;

    is $http_res->code,    101;
    is $http_res->message, 'Switching Protocols';
    is $http_res->headers->header('Connection'), 'Upgrade';
};

subtest 'builds string' => sub {
    my $res = _res()->new(key => uc 'k' x 16);

    is $res->to_string,
        "HTTP/1.1 101 Switching Protocols\r\n"
      . "Connection: Upgrade\r\n"
      . "Upgrade: WebSocket\r\n"
      . "Sec-WebSocket-Accept: vAxHsmERF4QGxY5H81SGLgxeESE=\r\n\r\n";
};

subtest 'builds psgi response' => sub {
    my $res = _res()->new(key => uc 'k' x 16);

    is_deeply $res->to_psgi,
      [
        101,
        [
            'Upgrade'              => 'WebSocket',
            'Connection'           => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE='
        ],
        []
      ];
};

subtest 'from http response' => sub {
    my $http_response = HTTP::Response->new(
        101,
        'Switching Protocols',
        [
            'Upgrade'              => 'WebSocket',
            'Connection'           => 'Upgrade',
            'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE='
        ],
    );

    my $res = _res()->from_http_response($http_response, key => uc 'k' x 16);

    is $res->code,    101;
    is $res->message, 'Switching Protocols';
    is_deeply $res->headers,
      [
        'Connection'           => 'Upgrade',
        'Upgrade'              => 'WebSocket',
        'Sec-WebSocket-Accept' => 'vAxHsmERF4QGxY5H81SGLgxeESE=',
      ];
};

sub _res { 'Protocol::WebSocket2::Handshake::Response' }

done_testing;
