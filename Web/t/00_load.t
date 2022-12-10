#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use File::Find;

my @NO_TEST = ( qw(  ) );

find(
    sub {
        return unless $_ =~ /\.pm$/;
        my $module = $File::Find::name;

        $module =~ s/\.pm//;
        $module =~ s/lib\///;
        $module =~ s/\//::/g;

        next if grep { $_ eq $module } @NO_TEST;
        use_ok( $module );
    }, 'lib'
);

done_testing();
