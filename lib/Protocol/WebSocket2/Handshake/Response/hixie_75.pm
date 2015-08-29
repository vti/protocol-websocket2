package Protocol::WebSocket2::Handshake::Response::hixie_75;

use strict;
use warnings;

use base 'Protocol::WebSocket2::Handshake::Response';

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}



1;
