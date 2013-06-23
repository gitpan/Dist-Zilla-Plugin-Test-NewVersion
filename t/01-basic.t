use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use Dist::Zilla::Tester;
use Cwd 'getcwd';
use Path::Tiny;

# build fake dist
my $tzil = Dist::Zilla::Tester->from_config({
    dist_root => path(qw(t corpus)),
});
$tzil->build;

my $orig_dir = getcwd;

my $build_dir = $tzil->tempdir->subdir('build');
chdir $build_dir;
my $file = path('xt', 'release', 'new-version.t');
ok( -e $file, 'test created');

my $contents = $file->slurp;
like($file->slurp, qr/q{$_}/, "test checks the $_ module") foreach qw(Foo Bar);

# run the tests
my $new_lib = path($build_dir, 'lib')->stringify;
unshift @INC, $new_lib;
note "running $new_lib...";
do $file;
chdir $orig_dir;

done_testing;
