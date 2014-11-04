package Dist::Zilla::Plugin::Bitbucket;

# ABSTRACT: Plugins to integrate Dist::Zilla with Bitbucket

use Moose 2.1400;
use Moose::Util::TypeConstraints 1.01;
use Config::Identity::Bitbucket;

=attr remote

Specifies the git/hg remote name to use (default 'origin').

=cut

has 'remote' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	default => 'origin',
);

=attr repo

Specifies the name of the Bitbucket repository to be created (by default the name
of the dist is used). This can be a template, so something like the following
will work:

	repo = {{ lc $dist -> name }}

=cut

has 'repo' => (
	is => 'ro',
	isa => 'Maybe[Str]',
);

=attr scm

Specifies the source code management system to use.

The possible choices are hg and git. It will be autodetected from the
distribution root directory if not provided.

=cut

has 'scm' => (
	is => 'ro',
	isa => enum( [ qw( hg git ) ] ),
	lazy => 1,
	default => sub {
		my $self = shift;

		# Does git exist?
		if ( -d '.git' ) {
			return 'git';
		} elsif ( -d '.hg' ) {
			return 'hg';
		} else {
			die "Unknown local repository type!";
		}
	},
);

sub _get_credentials {
	my ($self, $nopass) = @_;
## no critic (InputOutput::ProhibitBacktickOperators)
	my ($login, $pass);

	my %identity = Config::Identity::Bitbucket->load;

	if (%identity) {
		$login = $identity{'login'};
	} else {
		if ( $self->scm eq 'git' ) {
			$login = `git config bitbucket.user`;
		} else {
			$login = `hg showconfig bitbucket.user`;
		}
		chomp $login;
	}

	if (!$login) {
		my $error = %identity ?
			"Err: missing value 'user' in ~/.bitbucket" :
			"Err: Missing value 'bitbucket.user' in git/hg config";

		$self->log($error);
		return;
	}

	if (!$nopass) {
		if (%identity) {
			$pass  = $identity{'password'};
		} else {
			if ( $self->scm eq 'git' ) {
				$pass  = `git config bitbucket.password`;
			} else {
				$pass  = `hg showconfig bitbucket.password`;
			}
			chomp $pass;
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
	if ( $self->scm eq 'git' ) {
		if ($self->repo) {
			$repo = $self->repo;
		} else {
			require Git::Wrapper;
			my $git = Git::Wrapper->new('./');
			my ($url) = map { /Fetch URL: (.*)/ } $git->remote('show', '-n', $self->remote);

			if ($url =~ /bitbucket\.org.*?[:\/](.*)\.git$/) {
				$repo = $1;
			} else {
				$repo = $self->zilla->name;
			}
		}

		# Make sure we return full path including user
		if ($repo !~ /.*\/.*/) {
			($login, undef) = $self->_get_credentials(1);
			$repo = "$login/$repo";
		}
	} else {
		# Get it from .hgrc
		if ( -f '.hg/hgrc' ) {
			require File::Slurp::Tiny;
			my $hgrc = File::Slurp::Tiny::read_file( '.hg/hgrc' );

			# TODO this regex sucks.
			# apoc@box:~/test-hg$ cat .hg/hgrc
			#[paths]
			#default = ssh://hg@bitbucket.org/Apocal/test-hg
			if ( $hgrc =~ /default\s*=\s*(\S+)/ ) {
				$repo = $1;
				if ( $repo =~ /bitbucket\.org\/(.+)$/ ) {
					$repo = $1;
				} else {
					die "Unable to extract Bitbucket repo from hg: $repo";
				}
			} else {
				die "Unable to parse repo from hg: $hgrc";
			}
		} else {
			die "Unable to determine repository name as .hg/hgrc is nonexistent";
		}
	}
	$self->log_debug([ "Determined the repo name for Bitbucket is %s", $repo ]);
	return $repo;
}

no Moose;
__PACKAGE__ -> meta -> make_immutable;
1;

=pod

=head1 DESCRIPTION

This is a set of plugins for L<Dist::Zilla> intended
to more easily integrate L<Bitbucket|https://bitbucket.org> in the C<dzil> workflow.

The following is the list of the plugins shipped in this distribution:

=for :list
* L<Dist::Zilla::Plugin::Bitbucket::Create>
Create Bitbucket repo on dzil new
* L<Dist::Zilla::Plugin::Bitbucket::Update>
Update Bitbucket repo info on release
* L<Dist::Zilla::Plugin::Bitbucket::Meta>
Add Bitbucket repo info to META.{yml,json}

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
