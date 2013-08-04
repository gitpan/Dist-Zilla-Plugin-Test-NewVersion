use strict;
use warnings;
package Dist::Zilla::Plugin::Test::NewVersion;
{
  $Dist::Zilla::Plugin::Test::NewVersion::VERSION = '0.004';
}
# git description: v0.003-8-g10fa14a

BEGIN {
  $Dist::Zilla::Plugin::Test::NewVersion::AUTHORITY = 'cpan:ETHER';
}
# ABSTRACT: Generate a test that checks a new version has been assigned

use Moose;
with
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [ ':InstallModules' ],
    },
    'Dist::Zilla::Role::PrereqSource',
;
use Sub::Exporter::ForMethods 'method_installer';
use Data::Section 0.004 # fixed header_re
    { installer => Sub::Exporter::ForMethods::method_installer },
    '-setup';
use namespace::autoclean;

sub register_prereqs
{
    my $self = shift;
    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'develop',
        },
        'Test::More' => '0.88',
        'Encode' => '0',
        'LWP::UserAgent' => '0',
        'JSON' => '0',
        'Module::Runtime' => '0',
    );
}

has _test_file => (
    is => 'ro', isa => 'Dist::Zilla::File::InMemory',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $filename = 'xt/release/new-version.t';
        use Dist::Zilla::File::InMemory;
        Dist::Zilla::File::InMemory->new({
            name => $filename,
            content => ${$self->section_data($filename)},
        });
    },
);

sub gather_files
{
    my $self = shift;

    $self->add_file($self->_test_file);
    return;
}

sub munge_file
{
    my ($self, $file) = @_;

    # cannot check $file by name, as the file may have been moved by [ExtraTests].
    return unless $file eq $self->_test_file;

    require Module::Metadata;
    my @packages = map {
        open my $fh, '<', \( $_->content )
            or die 'Cannot create scalarref fh to read from ', $_->name, ": $!";
        Module::Metadata->new_from_handle($fh, $_->name)->name
    } @{ $self->found_files };

    $file->content(
        $self->fill_in_string(
            $file->content,
            {
                dist => \($self->zilla),
                packages => \@packages,
            },
        )
    );
    return;
}
__PACKAGE__->meta->make_immutable;

=pod

=encoding utf-8

=for :stopwords Karen Etheridge FileFinder irc

=head1 NAME

Dist::Zilla::Plugin::Test::NewVersion - Generate a test that checks a new version has been assigned

=head1 VERSION

version 0.004

=head1 SYNOPSIS

    # in dist.ini:
    [Test::NewVersion]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin generates a release test C<new-version.t>, which
checks the PAUSE index for latest version of each module, to confirm that
the version number(s) has been/have been incremented.

This is mostly useful only for distributions that do not automatically
increment their version from an external source, e.g.
L<Dist::Zilla::Plugin::Git::NextVersion>.

It is permitted for a module to have no version number at all, but if it is
set, it must have been incremented from the previous value, as otherwise this case
would be indistinguishable from developer error (forgetting to increment the
version), which is what we're testing for.  You can, however, explicitly
exclude some files from being checked, by passing your own
L<FileFinder|Dist::Zilla::Role::FileFinderUser/default_finders>.

=for Pod::Coverage register_prereqs gather_files munge_file

=head1 CONFIGURATION

This plugin takes as an optional setting:

=over 4

=item *

C<finders> - list the finder(s), one per line, that are to be used for

finding the modules to test.  Defaults to C<:InstallModules>; other
pre-defined options are listed in L<FileFinder|Dist::Zilla::Role::FileFinderUser/default_finders>.
You can define your own with the
L<Dist::Zilla::Plugin::FileFinder::ByName|[FileFinder::ByName]> plugin.

=back

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-Test-NewVersion>
(or L<bug-Dist-Zilla-Plugin-Test-NewVersion@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-Test-NewVersion@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

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

use Test::More 0.88;
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

done_testing;
__END__
