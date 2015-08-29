use strict;
use warnings;

use Test::More;
use Test::Fatal;

use HTTP::Request;
use URI;

use_ok 'Protocol::WebSocket2::Handshake::Request';

subtest 'default values' => sub {
    my $req = _req()->new(
        key => 'foo',
        url => URI->new('ws://localhost'),
    );

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'Upgrade'               => 'WebSocket',
            'Connection'            => 'Upgrade',
            'Host'                  => 'localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13,
        ]
      };
    is $req->method,   'GET';
    is $req->resource, '/';
};

subtest 'accepts url as a string' => sub {
    my $req = _req()->new(
        key => 'foo',
        url => 'ws://localhost',
    );

    is $req->resource, '/';
};

subtest 'throws on invalid url' => sub {
    like exception {
        _req()->new(
            key => 'foo',
            url => 'http://localhost',
          )
    }, qr/url does not look like a websocket/;
};

subtest 'from params' => sub {
    my $req = _req()->from_params(
        resource => '/',
        headers  => [
            upgrade                 => 'websocket',
            connection              => 'Upgrade',
            'Origin'                => 'http://localhost',
            'Host'                  => 'localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13
        ]
    );

    ok $req;
    is $req->url,      'ws://localhost/';
    is $req->method,   'GET';
    is $req->resource, '/';
};

subtest 'from params with url' => sub {
    my $req = _req()->from_params(
        url     => 'ws://localhost/',
        headers => [
            upgrade                 => 'websocket',
            connection              => 'Upgrade',
            'Origin'                => 'http://localhost',
            'Sec-WebSocket-Key'     => 'foo',
            'Sec-WebSocket-Version' => 13
        ]
    );

    ok $req;
    is $req->url,      'ws://localhost/';
    is $req->method,   'GET';
    is $req->resource, '/';
};

subtest 'from params with protocol' => sub {
    ok _req()->from_params(
        resource => '/',
        headers  => [
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
    ok _req()->from_params(
        resource => '/',
        headers  => [
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
    my $req = _req()->from_params(
        resource => '/',
        headers  => [
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
    my $req = _req()->new(key => 'foo', url => 'ws://localhost');

    my $res = $req->new_response;

    isa_ok $res, 'Protocol::WebSocket2::Handshake::Response';
};

subtest 'from psgi' => sub {
    my $env = {
        REQUEST_METHOD              => 'GET',
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

    my $req = _req()->from_psgi($env);

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/chat?foo=bar',
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

subtest 'from http request' => sub {
    my $http_req = HTTP::Request->new(
        GET => 'ws://localhost/chat?foo=bar',
        [
            Upgrade                  => 'WebSocket',
            Connection               => 'Upgrade',
            'Origin'                 => 'http://example.com',
            'Sec-WebSocket-Key'      => 'dGhlIHNhbXBsZSBub25jZQ==',
            'Sec-WebSocket-Protocol' => 'chat, superchat',
            'Sec-WebSocket-Version'  => 13,
        ]
    );

    my $req = _req()->from_http_request($http_req);

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/chat?foo=bar',
        headers  => [
            'Connection'             => 'Upgrade',
            'Upgrade'                => 'WebSocket',
            'Origin'                 => 'http://example.com',
            'Sec-WebSocket-Key'      => 'dGhlIHNhbXBsZSBub25jZQ==',
            'Sec-WebSocket-Protocol' => 'chat, superchat',
            'Sec-WebSocket-Version'  => 13,
            'Host'                   => 'localhost',
        ]
      };
};

subtest 'from http request without scheme' => sub {
    my $http_req = HTTP::Request->new(
        GET => '/chat?foo=bar',
        [
            Upgrade                  => 'WebSocket',
            Connection               => 'Upgrade',
            Host                     => 'localhost',
            'Origin'                 => 'http://example.com',
            'Sec-WebSocket-Key'      => 'dGhlIHNhbXBsZSBub25jZQ==',
            'Sec-WebSocket-Protocol' => 'chat, superchat',
            'Sec-WebSocket-Version'  => 13,
        ]
    );

    my $req = _req()->from_http_request($http_req);

    is $req->url, 'ws://localhost/chat?foo=bar';
};

subtest 'builds string request' => sub {
    my $req = _req()->new(url => 'ws://localhost/foo?bar=baz', key => '123');

    is $req->to_string,
        "GET /foo?bar=baz HTTP/1.1\r\n"
      . "Connection: Upgrade\r\n"
      . "Upgrade: WebSocket\r\n"
      . "Host: localhost\r\n"
      . "Sec-WebSocket-Key: 123\r\n"
      . "Sec-WebSocket-Version: 13\r\n\r\n";
};

sub _req { 'Protocol::WebSocket2::Handshake::Request' }

done_testing;
