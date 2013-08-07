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
    q{Dist::Zilla::Plugin::Test::NewVersion}
)
{
    my ($bumped, $message) = version_is_bumped($pkg);
    ok($bumped, $pkg . ' version is greater than version in index'
        . ( $message ? ( '(' . $message . ')' ) : '' )
    );
}

done_testing;