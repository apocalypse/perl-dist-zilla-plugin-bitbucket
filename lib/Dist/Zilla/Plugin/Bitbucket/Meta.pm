package Dist::Zilla::Plugin::Bitbucket::Meta;

# ABSTRACT: Add a Bitbucket repo's info to META.{yml,json}

use Moose;

extends 'Dist::Zilla::Plugin::Bitbucket';
with 'Dist::Zilla::Role::MetaProvider';

=attr homepage

The META homepage field will be set to the Bitbucket repository's
root if this option is set to true (default).

=cut

has 'homepage' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 1
);

=attr bugs

The META bugtracker web field will be set to the issue's page of the repository
on Bitbucket, if this options is set to true (default).

NOTE: Be sure to enable the issues section in the repository's
Bitbucket admin page!

=cut

has 'bugs' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 1
);

=attr wiki

The META homepage field will be set to the URL of the wiki of the Bitbucket
repository, if this option is set to true (default is false).

NOTE: Be sure to enable the wiki section in the repository's
Bitbucket admin page!

=cut

has 'wiki' => (
	is      => 'ro',
	isa     => 'Bool',
	default => 0
);

sub metadata {
	my $self    = shift;
	my ($opts)  = @_;

	my $repo_name = $self->_get_repo_name;
	return {} if (!$repo_name);

	my ($login, undef)  = $self->_get_credentials(1);
	return if (!$login);

	# Build the meta structure
	my $html_url = 'https://bitbucket.org/' . $login . '/' . $repo_name;
	my $meta = {
		'resources' => {
			'respository' => {
				'web' => $html_url,
				'url' => ( $self->scm eq 'git' ? 'git@bitbucket.org:' . $login . '/' . $repo_name . '.git' : $html_url ),
				'type' => $self->scm,
			},
		},
	};
	if ( $self->homepage and ! $self->wiki ) {
		# TODO we should use the API and fetch the current
		$meta->{'resources'}->{'homepage'} = $html_url;
	}
	if ( ! $self->homepage and $self->wiki ) {
		$meta->{'resources'}->{'homepage'} = $html_url . '/wiki/Home';
	}
	if ( $self->bugs ) {
		$meta->{'resources'}->{'bugtracker'} = {
			'web' => $html_url . '/issues'
		};
	}

	return $meta;
}

no Moose;
__PACKAGE__ -> meta -> make_immutable;
1;

=head1 SYNOPSIS

	# in dist.ini
	[Bitbucket::Meta]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds some information about the distribution's Bitbucket
repository to the META.{yml,json} files, using the official L<CPAN::Meta>
specification.

L<Bitbucket::Meta> currently sets the following fields:

=over 4

=item C<homepage>

The official home of this project on the web, taken from the Bitbucket repository
info. If the C<homepage> option is set to false this will be skipped (default is
true).

=item C<repository>

=over 4

=item C<web>

URL pointing to the Bitbucket page of the project.

=item C<url>

URL pointing to the Bitbucket repository (C<hg://...>).

=item C<type>

Either C<hg> or C<git> will be auto-detected and used.

=back

=item C<bugtracker>

=over 4

=item C<web>

URL pointing to the Bitbucket issues page of the project. If the C<bugs> option is
set to false (default is true) this will be skipped.

=back

=back

=cut
