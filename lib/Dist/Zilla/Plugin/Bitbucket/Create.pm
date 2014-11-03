package Dist::Zilla::Plugin::Bitbucket::Create;

# ABSTRACT: Create a new Bitbucket repo on dzil new

use Moose;
use Moose::Util::TypeConstraints;
use HTTP::Tiny 0.050;
use Try::Tiny 0.22;
use MIME::Base64 3.14;
use JSON::MaybeXS 1.002006 qw( encode_json decode_json );
use Git::Wrapper 0.037;
use File::pushd 1.009;

extends 'Dist::Zilla::Plugin::Bitbucket';
with 'Dist::Zilla::Role::AfterMint';
with 'Dist::Zilla::Role::TextTemplate';

=attr is_private

Create a private repository if this option is set to true, otherwise
create a private repository (default is false).

=cut

has 'is_private' => (
	is => 'ro',
	isa => 'Bool',
	default => 0
);

=attr prompt

Prompt for confirmation before creating a Bitbucket repository if this option is
set to true (default is false).

=cut

has 'prompt' => (
	is => 'ro',
	isa => 'Bool',
	default => 0
);

=attr has_issues

Enable issues for the new repository if this option is set to true (default).

=cut

has 'has_issues' => (
	is => 'ro',
	isa => 'Bool',
	default => 1
);

=attr has_wiki

Enable the wiki for the new repository if this option is set to true (default).

=cut

has 'has_wiki' => (
	is => 'ro',
	isa => 'Bool',
	default => 1
);

=attr description

Provide a string describing the repository. Defaults to nothing.

NOTE: If you are also using the L<Dist::Zilla::Plugin::Bitbucket::Update> plugin watch out for it clobbering your description on release!

=cut

has 'description' => (
	is => 'ro',
	isa => 'Maybe[Str]',
);

=attr fork_policy

Control the rules for forking this repository. Available values are (the default is allow_forks):

	allow_forks: unrestricted forking
	no_public_forks: restrict forking to private forks (forks cannot be made public later)
	no_forks: deny all forking

=cut

has 'fork_policy' => (
	is => 'ro',
	isa => enum( [ qw( allow_forks no_public_forks no_forks ) ] ),
	default => 'allow_forks',
);

=attr language

The programming language used in the repository. Defaults to nothing.

NOTE: Must be a valid (lowercase) item as shown in the drop-down list on the repository's admin page on the Bitbucket website.

=cut

has 'language' => (
	is => 'ro',
	isa => 'Maybe[Str]',
);

sub after_mint {
	my $self   = shift;
	my ($opts) = @_;

	return if $self->prompt and not $self->_confirm;

	my $root = $opts->{'mint_root'};

	my $repo_name;

	if ($opts->{'repo'}) {
		$repo_name = $opts->{'repo'};
	} elsif ($self->repo) {
		$repo_name = $self->fill_in_string( $self->repo, { dist => \($self->zilla) }, );
	} else {
		$repo_name = $self->zilla->name;
	}

	# set the repo settings
	my ($params, $headers);
	$params->{'name'} = $repo_name;
	$params->{'is_private'} = 'true' if $self->is_private;
	$params->{'description'} = $self->description if $self->description;
	$params->{'fork_policy'} = $self->fork_policy;
	$params->{'language'} = $self->language if $self->language;

	$params->{'has_issues'} = $self->has_issues ? 'true' : 'false';
	$self->log_debug([ 'Issues are %s', $params -> {'has_issues'} ? 'enabled' : 'disabled' ]);

	$params->{'has_wiki'} = $self->has_wiki ? 'true' : 'false';
	$self->log_debug([ 'Wiki is %s', $params -> {'has_wiki'} ? 'enabled' : 'disabled' ]);

	{
		# we are in a completely different path and as such the auto-detection logic won't work!
		my $p = pushd( $root );
		$params->{'scm'} = $self->scm;
	}

	# construct the HTTP request!
	my $http = HTTP::Tiny->new;
	my ($login, $pass)  = $self->_get_credentials(0);
	$headers->{'authorization'} = "Basic " . MIME::Base64::encode_base64("$login:$pass", '');
	$headers->{'content-type'} = "application/json";

	# We use the v2.0 API to create
	my $url = 'https://api.bitbucket.org/2.0/repositories/' . $login . '/' . $repo_name; # TODO encode the repo_name and login?
	$self->log([ "Creating new Bitbucket repository '%s'", $repo_name ]);
	my $response = $http->request( 'POST', $url, {
		content => encode_json( $params ),
		headers => $headers
	});

	if ( ! $response->{'success'} ) {
		$self->log( ["Error: HTTP status(%s) when trying to POST => %s", $response->{'status'}, $response->{'reason'} ] );
		return;
	}

	my $r = decode_json( $response->{'content'} );
	if ( ! $r ) {
		$self->log( "ERROR: Malformed response content when trying to POST" );
		return;
	}
	if ( exists $r->{'error'} ) {
		$self->log( [ "Unable to create new Bitbucket repository: %s", $r->{'error'} ] );
		return;
	}

	# Now, we add the remote!
	if ( $self->scm eq 'git' ) {
		my $git_dir = "$root/.git";
		my $rem_ref = $git_dir . "/refs/remotes/" . $self->remote;

		if ((-d $git_dir) && (not -d $rem_ref)) {
			my $git = Git::Wrapper->new($root);

			$self->log_debug([ "Setting Bitbucket remote '%s'", $self->remote ]);

			$git->remote("add", $self->remote, 'git@bitbucket.org:' . $login . '/' . $repo_name . '.git');

			my ($branch) = try { $git->rev_parse( { abbrev_ref => 1, symbolic_full_name => 1 }, 'HEAD' ) };

			if ($branch) {
				try {
					$git->config("branch.$branch.merge");
					$git->config("branch.$branch.remote");
				} catch {
					$self->log_debug([ "Setting up remote tracking for branch '%s'", $branch ]);

					$git->config("branch.$branch.merge", "refs/heads/$branch");
					$git->config("branch.$branch.remote", $self->remote);
				};
			}
		}
	} else {
		# TODO hg doesn't seem to have the same equivalent as git remote - we have to push!
		my $cmd = 'hg push ssh://hg@bitbucket.org/' . $login . '/' . $repo_name;

		# TODO we need a Hg::Wrapper! :)
		`$cmd`;
	}
}

sub _confirm {
	my ($self) = @_;

	my $prompt = "Shall I create a Bitbucket repository for " . $self->zilla->name . "?";
	return $self->zilla->chrome->prompt_yn($prompt, {default => 1} );
}

no Moose;
__PACKAGE__ -> meta -> make_immutable;
1;

=pod

=head1 SYNOPSIS

	# in your profile.ini in the MintingProvider's profile
	[Bitbucket::Create]

	# to override publicness
	[Bitbucket::Create]
	public = 0

	# use a template for the repository name
	[Bitbucket::Create]
	repo = {{ lc $dist -> name }}

See L</ATTRIBUTES> for more options.

=head1 DESCRIPTION

This L<Dist::Zilla> plugin creates a new git repository on L<Bitbucket|https://bitbucket.org> when
a new distribution is created with C<dzil new>.

It will also add a new git remote pointing to the newly created Bitbucket
repository's private URL. See L</"ADDING REMOTE"> for more info.

Furthermore, please consult the Bitbucket API reference at
L<https://confluence.atlassian.com/display/BITBUCKET/repository+Resource#repositoryResource-POSTanewrepository>
for an in-depth explanation of the various settings.

=head1 ADDING REMOTE

By default C<Bitbucket::Create> adds a new git remote pointing to the newly created
Bitbucket repository's private URL B<if, and only if,> a git repository has already
been initialized, and if the remote doesn't already exist in that repository.

To take full advantage of this feature you should use, along with C<Bitbucket::Create>,
the L<Dist::Zilla::Plugin::Git::Init> plugin, leaving blank its C<remote> option,
as follows:

	[Git::Init]
	; here goes your Git::Init config, remember
	; to not set the 'remote' option
	[Bitbucket::Create]

You may set your preferred remote name, by setting the C<remote> option of the
C<Bitbucket::Create> plugin, as follows:

	[Git::Init]
	[Bitbucket::Create]
	remote = myremote

Remember to put C<[Git::Init]> B<before> C<[Bitbucket::Create]>.

After the new remote is added, the current branch will track it, unless remote
tracking for the branch was already set. This may allow one to use the
L<Dist::Zilla::Plugin::Git::Push> plugin without the need to do a C<git push>
between the C<dzil new> and C<dzil release>. Note though that this will work
only when the C<push.default> Git configuration option is set to either
C<upstream> or C<simple> (which will be the default in Git 2.0). If you are
using an older Git or don't want to change your config, you may want to have a
look at L<Dist::Zilla::Plugin::Git::PushInitial>.

=head2 Mercurial usage

This author admits to being a newbie to Mercurial (hg) and haven't tested it thoroughly! In theory this
plugin should play nice with the L<Dist::Zilla::Plugin::Mercurial> dist so please let me know if you encounter
issues!

=cut
