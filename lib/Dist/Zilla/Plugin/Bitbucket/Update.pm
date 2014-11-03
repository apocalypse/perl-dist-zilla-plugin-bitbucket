package Dist::Zilla::Plugin::Bitbucket::Update;

# ABSTRACT: Update a GitHub repo's info on release

use JSON;
use Moose;

extends 'Dist::Zilla::Plugin::Bitbucket';

with 'Dist::Zilla::Role::AfterRelease';

has 'cpan' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 1
);

has 'p3rl' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0
);

has 'metacpan' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0
);

has 'meta_home' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0
);

=head1 SYNOPSIS

	# in your profile.ini in the MintingProvider's profile
	[Bitbucket::Update]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin updates the information of the Bitbucket repository
when C<dzil release> is run.

=cut

sub after_release {
	my $self      = shift;
	my ($opts)    = @_;
	my $dist_name = $self -> zilla -> name;

	my ($login, $pass, $otp)  = $self -> _get_credentials(0);
	return if (!$login);

	my $repo_name = $self -> _get_repo_name($login);

	my $http = HTTP::Tiny -> new;

	$self -> log("Updating GitHub repository info");

	my ($params, $headers, $content);

	$repo_name =~ /\/(.*)$/;
	my $repo_name_only = $1;

	$params -> {'name'} = $repo_name_only;
	$params -> {'description'} = $self -> zilla -> abstract;

	my $meta_home = $self -> zilla -> distmeta
		-> {'resources'} -> {'homepage'};

	if ($meta_home && $self -> meta_home) {
		$self -> log("Using distmeta URL");
		$params -> {'homepage'} = $meta_home;
	} elsif ($self -> metacpan == 1) {
		$self -> log("Using MetaCPAN URL");
		$params -> {'homepage'} =
			"http://metacpan.org/release/$dist_name/"
	} elsif ($self -> p3rl == 1) {
		my $guess_name = $dist_name;
		$guess_name =~ s/\-/\:\:/g;

		$self -> log("Using P3rl URL");
		$params -> {'homepage'} = "http://p3rl.org/$guess_name"
	} elsif ($self -> cpan == 1) {
		$self -> log("Using CPAN URL");
		$params -> {'homepage'} =
			"http://search.cpan.org/dist/$dist_name/"
	}

	my $url = $self -> api."/repos/$repo_name";

	if ($pass) {
		require MIME::Base64;

		my $basic = MIME::Base64::encode_base64("$login:$pass", '');
		$headers -> {'Authorization'} = "Basic $basic";
	}

	if ($self -> prompt_2fa) {
		$headers -> { 'X-GitHub-OTP' } = $otp;
		$self -> log([ "Using two-factor authentication" ]);
	}

	$content = to_json $params;

	my $response = $http -> request('PATCH', $url, {
		content => $content,
		headers => $headers
	});

	my $repo = $self -> _check_response($response);

	if ($repo eq 'redo') {
		$self -> log("Retrying with two-factor authentication");
		$self -> prompt_2fa(1);
		$repo = $self -> after_release($opts);
	}

	return if not $repo;
}

=head1 ATTRIBUTES

=over

=item C<repo>

The name of the GitHub repository. By default the name will be extracted from
the URL of the remote specified in the C<remote> option, and if that fails the
dist name (from dist.ini) is used. It can also be in the form C<user/repo>
when it belongs to another GitHub user/organization.

=item C<remote>

The name of the Git remote pointing to the GitHub repository (C<"origin"> by
default). This is used when trying to guess the repository name.

=item C<cpan>

The GitHub homepage field will be set to the CPAN page (search.cpan.org) of the
module if this option is set to true (default),

=item C<p3rl>

The GitHub homepage field will be set to the p3rl.org shortened URL
(e.g. C<http://p3rl.org/My::Module>) if this option is set to true (default is
false).

This takes precedence over the C<cpan> option (if both are true, p3rl will be
used).

=item C<metacpan>

The GitHub homepage field will be set to the metacpan.org distribution URL
(e.g. C<http://metacpan.org/release/My-Module>) if this option is set to true
(default is false).

This takes precedence over the C<cpan> and C<p3rl> options (if all three are
true, metacpan will be used).

=item C<meta_home>

The GitHub homepage field will be set to the value present in the dist meta
(e.g. the one set by other plugins) if this option is set to true (default is
false). If no value is present in the dist meta, this option is ignored.

This takes precedence over the C<metacpan>, C<cpan> and C<p3rl> options (if all
four are true, meta_home will be used).

=item C<prompt_2fa>

Prompt for GitHub two-factor authentication code if this option is set to true
(default is false). If this option is set to false but GitHub requires 2fa for
the login, it'll be automatically enabled.

=back

=cut

no Moose;
__PACKAGE__ -> meta -> make_immutable;
1;
