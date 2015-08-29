use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket2::Handshake::Request::hixie_75';

subtest 'default values' => sub {
    my $req = _req()->new(url => 'ws://localhost');

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'Upgrade'    => 'WebSocket',
            'Connection' => 'Upgrade',
            'Host'       => 'localhost',
            'Origin'     => 'http://localhost',
        ]
      };
};

subtest 'from params' => sub {
    my $req = _req()->from_params(
        method   => 'GET',
        resource => '/',
        headers  => [
            'upgrade'    => 'websocket',
            'connection' => 'Upgrade',
            'Origin'     => 'http://localhost',
            'Host'       => 'localhost',
        ]
    );

    ok $req;
    is $req->url, 'ws://localhost/';
};

subtest 'round' => sub {
    my $req = _req()->from_params(
        resource => '/',
        headers  => [
            upgrade    => 'websocket',
            connection => 'Upgrade',
            'Host'     => 'localhost',
            'Origin'   => 'http://localhost',
        ]
    );

    is_deeply { $req->to_params },
      {
        method   => 'GET',
        resource => '/',
        headers  => [
            'upgrade'    => 'websocket',
            'connection' => 'Upgrade',
            'Host'       => 'localhost',
            'Origin'     => 'http://localhost',
        ]
      };
};

subtest 'builds new response' => sub {
    my $req = _req()->new(url => 'ws://localhost');

    my $res = $req->new_response;

    isa_ok $res, 'Protocol::WebSocket2::Handshake::Response';
};

sub _req {
    'Protocol::WebSocket2::Handshake::Request::hixie_75';
}

done_testing;
