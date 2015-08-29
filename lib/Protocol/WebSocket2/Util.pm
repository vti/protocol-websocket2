package Protocol::WebSocket2::Util;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(is_legacy dispatch_legacy header_exists header_get header_get_lc);

use List::Util qw(first);

sub is_legacy {
    my ($version) = @_;

    return 1 if$version && $version ne 'rfc6455';

    return 0;
}

sub dispatch_legacy {
    my (%params) = @_;

    my $version = $params{version};

    $version =~ s{-}{_}g;
    my $class = (caller)[0] . '::' . $version;
    return $class->new(%params);
}

sub header_get ($$) {
    my ($headers, $header) = @_;

    for (my $i = 0; $i < @$headers; $i += 2) {
        return $headers->[$i + 1] if lc($headers->[$i]) eq lc($header);
    }

    return '';
}

sub header_get_lc ($$) {
    my ($headers, $header) = @_;

    my $value = header_get($headers, $header);
    return unless defined $value;

    return lc $value;
}

1;
