use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use Dist::Zilla::Tester;
use Path::Tiny;

# build fake dist
my $tzil = Dist::Zilla::Tester->from_config({
    dist_root => path(qw(t corpus file-from-code)),
});
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = path($build_dir, 'xt', 'release', 'new-version.t');
ok( -e $file, 'test created');

my $contents = $file->slurp;
like($file->slurp, qr/q{\Q$_\E}/, "test checks the $_ module") foreach qw(Foo ExtUtils::MakeMaker);

# run the tests
my $new_lib = path($build_dir, 'lib')->stringify;
unshift @INC, $new_lib;

subtest "running $new_lib..." => sub {
    do $file;
};

done_testing;
