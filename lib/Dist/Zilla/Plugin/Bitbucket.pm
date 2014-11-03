package Dist::Zilla::Plugin::Bitbucket;

# ABSTRACT: Plugins to integrate Dist::Zilla with Bitbucket

use Moose;
use Git::Wrapper;
use Class::Load qw(try_load_class);

=attr remote

Specifies the git remote name to be added (default 'origin'). This will point to
the newly created GitHub repository's private URL. See L</"ADDING REMOTE"> for
more info.

=cut

has 'remote' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	default => 'origin'
);

=attr repo

Specifies the name of the GitHub repository to be created (by default the name
of the dist is used). This can be a template, so something like the following
will work:

	repo = {{ lc $dist -> name }}

=cut

has 'repo' => (
	is => 'ro',
	isa => 'Maybe[Str]'
);

has 'api'  => (
	is => 'ro',
	isa => 'Str',
	default => 'https://api.bitbucket.org/2.0/'
);

sub _get_credentials {
	my ($self, $nopass) = @_;

	my ($login, $pass);

	my %identity = Config::Identity::Bitbucket -> load
		if try_load_class('Config::Identity::Bitbucket');

	if (%identity) {
		$login = $identity{'login'};
	} else {
		$login = `git config bitbucket.user`;  chomp $login;
	}

	if (!$login) {
		my $error = %identity ?
			"Err: missing value 'user' in ~/.bitbucket" :
			"Err: Missing value 'bitbucket.user' in git config";

		$self->log($error);
		return;
	}

	if (!$nopass) {
		if (%identity) {
			$pass  = $identity{'password'};
		} else {
			$pass  = `git config bitbucket.password`; chomp $pass;
		}

		if (!$pass) {
			$pass = $self->zilla->chrome->prompt_str( "Bitbucket password for '$login'", { noecho => 1 } );
		}
	}

	return ($login, $pass);
}

sub _get_repo_name {
	my ($self, $login) = @_;

	my $repo;
	my $git = Git::Wrapper->new('./');

	$repo = $self->repo if $self->repo;

	my ($url) = map /Fetch URL: (.*)/,
		$git -> remote('show', '-n', $self -> remote);

	$url =~ /bitbucket\.org.*?[:\/](.*)\.git$/;
	$repo = $1 unless $repo and not $1;

	$repo = $self->zilla->name unless $repo;

	if ($repo !~ /.*\/.*/) {
		($login, undef) = $self -> _get_credentials(1);

		$repo = "$login/$repo";
	}

	return $repo;
}

no Moose;
__PACKAGE__ -> meta -> make_immutable;
1;

=pod

=head1 SYNOPSIS

	# in plugin.ini
	[Bitbucket::Create]

	# in dist.ini
	[Bitbucket::Update]
	[Bitbucket::Meta]

=head1 DESCRIPTION

This is a set of plugins for L<Dist::Zilla> intended
to more easily integrate L<Bitbucket|https://bitbucket.org> in the C<dzil> workflow.

The following is the list of the plugins shipped in this distribution:

=over 4

=item * L<Dist::Zilla::Plugin::Bitbucket::Create> Create Bitbucket repo on dzil new

=item * L<Dist::Zilla::Plugin::Bitbucket::Update> Update Bitbucket repo info on release

=item * L<Dist::Zilla::Plugin::Bitbucket::Meta> Add Bitbucket repo info to META.{yml,json}

=back

=head2 Configuration

Configure git with your Bitbucket credentials:

	$ git config --global bitbucket.user LoginName
	$ git config --global bitbucket.password MySecretPassword

Alternatively you can install L<Config::Identity> and write your credentials
in the (optionally GPG-encrypted) C<~/.bitbucket> file as follows:

	login LoginName
	password MySecretPassword

(if only the login name is set, the password will be asked interactively)

=head1 ACKNOWLEDGEMENTS

This dist was shamelessly copied from ALEXBIO's excellent L<Dist::Zilla::Plugin::GitHub> :)

I didn't implement the PluginBundle nor the Command::gh modules as I didn't have a need for them. Please
let me know if you want them!

=cut
