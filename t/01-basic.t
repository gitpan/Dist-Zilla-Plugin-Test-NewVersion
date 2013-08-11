use strict;
use warnings FATAL => 'all';

use Test::Tester 0.108;
use Test::More;
use Test::Warnings ':no_end_test';
use Dist::Zilla::Tester;
use Path::Tiny;
use Cwd 'getcwd';
use Test::Deep;

# let us find our inc/ dir
unshift @INC, 't/corpus/basic';

# build fake dist
my $tzil = Dist::Zilla::Tester->from_config({
    dist_root => path(qw(t corpus basic)),
});
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = path($build_dir, 'xt', 'release', 'new-version.t');
ok( -e $file, 'test created');

my $contents = $file->slurp;
like($file->slurp, qr/q{\Q$_\E}/, "test checks the $_ module") foreach qw(
    lib/Foo.pm
    lib/Bar/Baz.pm
    lib/Plack/Test.pm
    lib/Moose.pm
    lib/Moose/Cookbook.pod
);

# run the tests

my $cwd = getcwd;
chdir $build_dir;

my $new_lib = path($build_dir, 'lib')->stringify;
unshift @INC, $new_lib;

subtest "running $new_lib..." => sub {
    my ($premature, @results) = run_tests(sub {
        # prevent done_testing from performing a warnings check
        {
            package Test::Tester::Delegate;
            sub in_subtest { 1 }
        }

        # Test::Tester cannot handle calls to done_testing?!
        no warnings 'redefine';
        local *Test::Builder::done_testing = sub { };

        do $file;
        diag "got error: $@\n" if $@;
    });

    # this somewhat redundant test allows an easier way of seeing which tests failed
    cmp_deeply(
        [ map { $_->{name} } @results ],
        bag(
            'Foo (lib/Foo.pm) VERSION is ok (not indexed)',
            'Bar::Baz (lib/Bar/Baz.pm) VERSION is ok (not indexed)',
            'Plack::Test (lib/Plack/Test.pm) VERSION is ok (VERSION is not set in index)',
            re(qr{^Moose \(lib/Moose\.pm\) VERSION is ok \(VERSION is not set; indexed version is \d.\d+\)$}),
            re(qr{^ExtUtils::MakeMaker \(lib/ExtUtils\/MakeMaker\.pm\) VERSION is ok \(indexed at \d.\d+; local version is 100\.0\)$}),
            re(qr{^Moose::Cookbook \(lib/Moose\/Cookbook\.pod\) VERSION is ok \(indexed at \d.\d+; local version is 20\.0\)$}),
        ),
        'expected tests ran',
    )
    or diag('ran tests: ', do { require Data::Dumper; Data::Dumper::Dumper([map { $_->{name} } @results ]) });

    cmp_deeply(
        \@results,
        bag(
            superhashof({
                name => 'Foo (lib/Foo.pm) VERSION is ok (not indexed)',
                ok => 1, actual_ok => 1,
                depth => 2, type => '', diag => '',
            }),
            superhashof({
                name => 'Bar::Baz (lib/Bar/Baz.pm) VERSION is ok (not indexed)',
                ok => 1, actual_ok => 1,
                depth => 2, type => '', diag => '',
            }),
            superhashof({
                name => 'Plack::Test (lib/Plack/Test.pm) VERSION is ok (VERSION is not set in index)',
                ok => 1, actual_ok => 1,
                depth => 2, type => '', diag => '',
            }),
            superhashof({
                name => re(qr{^Moose \(lib/Moose\.pm\) VERSION is ok \(VERSION is not set; indexed version is \d.\d+\)$}),
                ok => 0, actual_ok => 0,
                depth => 2, type => '', diag => '',
            }),
            superhashof({
                name => re(qr{^ExtUtils::MakeMaker \(lib/ExtUtils\/MakeMaker\.pm\) VERSION is ok \(indexed at \d.\d+; local version is 100\.0\)$}),
                ok => 1, actual_ok => 1,
                depth => 2, type => '', diag => '',
            }),
            superhashof({
                name => re(qr{^Moose::Cookbook \(lib/Moose\/Cookbook\.pod\) VERSION is ok \(indexed at \d.\d+; local version is 20\.0\)$}),
                ok => 1, actual_ok => 1,
                depth => 2, type => '', diag => '',
            }),
        ),
        'our expected tests ran correctly',
    );
};

chdir $cwd;

Test::Warnings::had_no_warnings('no (unexpected) warnings');
done_testing;
