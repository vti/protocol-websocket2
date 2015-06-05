use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::Handshake::Request';

subtest 'default values' => sub {
    my $req = _build_req(
        key      => 'foo',
        host     => 'localhost',
        origin   => 'http://localhost',
        resource => '/'
    );

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'Upgrade'               => 'WebSocket',
            'Connection'            => 'Upgrade',
            'Host'                  => 'localhost',
            'Origin'                => 'http://localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13,
        ]
      };
};

subtest 'from params' => sub {
    my $req = _build_req();

    ok $req->from_params(
        headers => [
            upgrade                 => 'websocket',
            connection              => 'Upgrade',
            'Origin'                => 'http://localhost',
            'Host'                  => 'localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13
        ]
    );
};

subtest 'from params with protocol' => sub {
    my $req = _build_req();

    ok $req->from_params(
        headers => [
            upgrade                  => 'websocket',
            connection               => 'Upgrade',
            'Origin'                 => 'http://localhost',
            'Host'                   => 'localhost',
            'Sec-WebSocket-Key'      => 'foo',
            'Sec-WebSocket-Version'  => 13,
            'Sec-WebSocket-Protocol' => 'chat, superchat',
        ]
    );
};

subtest 'from params with special connection' => sub {
    my $req = _build_req();

    ok $req->from_params(
        headers => [
            upgrade                 => 'websocket',
            connection              => 'keep-alive, Upgrade',
            'Host'                  => 'localhost',
            'Origin'                => 'http://localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13
        ]
    );
};

subtest 'round' => sub {
    my $req = _build_req();

    ok $req->from_params(
        headers => [
            upgrade                  => 'websocket',
            connection               => 'keep-alive, Upgrade',
            'Host'                   => 'localhost',
            'Origin'                 => 'http://localhost',
            'Sec-WebSocket-Key'      => 'foo',
            'Sec-WebSocket-Version'  => 13,
            'Sec-WebSocket-Protocol' => 'chat',
        ]
    );

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'upgrade'                => 'websocket',
            'connection'             => 'keep-alive, Upgrade',
            'Host'                   => 'localhost',
            'Origin'                 => 'http://localhost',
            'Sec-WebSocket-Key'      => 'foo',
            'Sec-WebSocket-Version'  => 13,
            'Sec-WebSocket-Protocol' => 'chat',
        ]
      };
};

subtest 'builds new response' => sub {
    my $req = _build_req(key => 'foo');

    my $res = $req->new_response;

    isa_ok $res, 'Protocol::WebSocket2::Handshake::Response';
};

subtest 'from psgi' => sub {
    my $req = _build_req(key => 'foo');

    my $env = {
        SCRIPT_NAME                 => '',
        PATH_INFO                   => '/chat',
        QUERY_STRING                => 'foo=bar',
        HTTP_UPGRADE                => 'websocket',
        HTTP_CONNECTION             => 'Upgrade',
        HTTP_HOST                   => 'server.example.com',
        HTTP_COOKIE                 => 'foo=bar',
        HTTP_ORIGIN                 => 'http://example.com',
        HTTP_SEC_WEBSOCKET_PROTOCOL => 'chat, superchat',
        HTTP_SEC_WEBSOCKET_KEY      => 'dGhlIHNhbXBsZSBub25jZQ==',
        HTTP_SEC_WEBSOCKET_VERSION  => 13
    };

    $req = $req->from_psgi($env);

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'connection'             => 'Upgrade',
            'cookie'                 => 'foo=bar',
            'host'                   => 'server.example.com',
            'origin'                 => 'http://example.com',
            'sec-websocket-key'      => 'dGhlIHNhbXBsZSBub25jZQ==',
            'sec-websocket-protocol' => 'chat, superchat',
            'sec-websocket-version'  => 13,
            'upgrade'                => 'websocket',
        ]
      };
};

sub _build_req { Protocol::WebSocket2::Handshake::Request->new(@_) }

done_testing;
