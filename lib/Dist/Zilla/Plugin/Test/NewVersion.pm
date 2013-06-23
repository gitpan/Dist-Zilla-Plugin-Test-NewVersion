use strict;
use warnings;
package Dist::Zilla::Plugin::Test::NewVersion;
{
  $Dist::Zilla::Plugin::Test::NewVersion::VERSION = '0.001';
}
# git description: be88591

BEGIN {
  $Dist::Zilla::Plugin::Test::NewVersion::AUTHORITY = 'cpan:ETHER';
}
# ABSTRACT: Generate a test that checks a new version has been assigned

use Moose;
with
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [ ':InstallModules' ],
    },
;
use Sub::Exporter::ForMethods 'method_installer';
use Data::Section 0.004 # fixed header_re
    { installer => Sub::Exporter::ForMethods::method_installer },
    '-setup';
use namespace::autoclean;

sub gather_files
{
    my $self = shift;

    my $filename = 'xt/release/new-version.t';

    # generate $filename with $content...

    require Module::Metadata;
    require Dist::Zilla::File::FromCode;

    my @files = @{ $self->found_files };
    my @packages = map {
        Module::Metadata->new_from_file($_->name)->name
    } @files;

    my $file  = Dist::Zilla::File::FromCode->new({
        name => $filename,
        code => sub {
            my $content = $self->fill_in_string(
                ${$self->section_data($filename)},
                {
                    dist => \($self->zilla),
                    packages => \@packages,
                },
            );
            $content;
        },
    });

    $self->add_file($file);
    return;
}

=pod

=encoding utf-8

=for :stopwords Karen Etheridge

=head1 NAME

Dist::Zilla::Plugin::Test::NewVersion - Generate a test that checks a new version has been assigned

=head1 VERSION

version 0.001

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
___[ xt/release/new-version.t ]___
use strict;
use warnings FATAL => 'all';

use Encode;
use LWP::UserAgent;
use JSON;
use Module::Runtime 'use_module';

# returns bool, detailed message
sub version_is_bumped
{
    my $pkg = shift;

    my $ua = LWP::UserAgent->new(keep_alive => 1);
    $ua->env_proxy;

    my $res = $ua->get("http://cpanidx.org/cpanidx/json/mod/$pkg");
    unless ($res->is_success) {
        return (1, $pkg . ' not found in index - first release, perhaps?');
    }

    # JSON wants UTF-8 bytestreams, so we need to re-encode no matter what
    # encoding we got. -- rjbs, 2011-08-18 (in Dist::Zilla)
    my $json_octets = Encode::encode_utf8($res->decoded_content);
    my $payload = JSON::->new->decode($json_octets);

    unless (\@$payload) {
        return (0, 'no valid JSON returned');
    }

    my $current_version = use_module($pkg)->VERSION;
    return (0, $pkg . ' version is not set') if not defined $current_version;

    my $indexed_version = version->parse($payload->[0]{mod_vers});
    return (1) if $indexed_version < $current_version;

    return (0, $pkg . ' is indexed at: ' . $indexed_version . '; local version is ' . $current_version);
}

foreach my $pkg (
{{ join(",\n", map { '    q{' . $_ . '}' } @packages) }}
)
{
    my ($bumped, $message) = version_is_bumped($pkg);
    ok($bumped, $pkg . ' version is greater than version in index');
    note $message if $message;
}
__END__

=pod

=head1 SYNOPSIS

    # in dist.ini:
    [Test::NewVersion]

=head1 DESCRIPTION

=for stopwords FileFinder

This L<Dist::Zilla> plugin generates a release test C<new-version.t>, which
checks the PAUSE index for latest version of each module, to confirm that
the version number(s) has been/have been incremented.

This is mostly useful only for distributions that do not automatically
increment their version from an external source, e.g.
L<Dist::Zilla::Plugin::Git::NextVersion>.

It is permitted for a module to have no version number at all, but if it is
set, it have been incremented from the previous value, as otherwise this case
would be indistinguishable from developer error (forgetting to increment the
version), which is what we're testing for.  You can, however, explicitly
exclude some files from being checked, by passing your own
L<FileFinder|Dist::Zilla::Role::FileFinderUser/default_finders>.

=for Pod::Coverage gather_files

=head1 CONFIGURATION

This plugin takes as an optional setting:

=begin :list

* C<finders> - list the finder(s), one per line, that are to be used for
finding the modules to test.  Defaults to C<:InstallModules>; other
pre-defined options are listed in L<FileFinder|Dist::Zilla::Role::FileFinderUser/default_finders>.
You can define your own with the
L<Dist::Zilla::Plugin::FileFinder::ByName|[FileFinder::ByName]> plugin.

=end :list

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-Test-NewVersion>
(or L<bug-Dist-Zilla-Plugin-Test-NewVersion@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-Test-NewVersion@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
