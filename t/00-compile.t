use strict;
use warnings;

# This test was generated via Dist::Zilla::Plugin::Test::Compile 2.006

use Test::More 0.94;



use File::Temp qw{ tempdir };
use Capture::Tiny qw{ capture };

my @module_files = qw(
lib/Dist/Zilla/Plugin/Test/NewVersion.pm
);

my @scripts = qw(

);

{
    # no fake home requested

    my @warnings;
    for my $lib (sort @module_files)
    {
        my ($stdout, $stderr, $exit) = capture {
            system($^X, '-Ilib', '-e', qq{require qq[$lib]});
        };
        is($?, 0, "$lib loaded ok");
        warn $stderr if $stderr;
        push @warnings, $stderr if $stderr;
    }

    if ($ENV{AUTHOR_TESTING}) { is(scalar(@warnings), 0, 'no warnings found'); }

if (@scripts) {
    SKIP: {
        eval "use Test::Script 1.05; 1;";
        skip "Test::Script needed to test script compilation", scalar(@scripts) if $@;
        foreach my $file ( @scripts ) {
            my $script = $file;
            $script =~ s!.*/!!;
            script_compiles( $file, "$script script compiles" );
        }
    }
}

    BAIL_OUT("Compilation problems") if !Test::More->builder->is_passing;
}

done_testing;
