package Dist::Zilla::Plugin::Bitbucket::Update;

# ABSTRACT: Update a Bitbucket repo's info on release

use Moose;
use HTTP::Tiny 0.050;
use MIME::Base64 3.14;
use JSON::MaybeXS 1.002006 qw( encode_json decode_json );

extends 'Dist::Zilla::Plugin::Bitbucket';
with 'Dist::Zilla::Role::AfterRelease';

sub after_release {
	my $self = shift;

	my ($login, $pass)  = $self->_get_credentials(0);
	return if (!$login);

	my $repo_name = $self->_get_repo_name(1);

	# set the repo settings
	my ($params, $headers);
	$params->{'description'} = $self->zilla->abstract;
	$params->{'website'} = $self->zilla->distmeta->{'resources'}{'homepage'};

	# construct the HTTP request!
	my $http = HTTP::Tiny->new;
	$headers->{'authorization'} = "Basic " . MIME::Base64::encode_base64("$login:$pass", '');
	$headers->{'content-type'} = "application/json";

	# We use the v1.0 API to update
	my $url = 'https://bitbucket.org/api/1.0/repositories/' . $repo_name; # TODO encode the repo_name?
	$self->log( "Updating Bitbucket repository info" );
	my $response = $http->request( 'PUT', $url, {
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
		$self->log( [ "Unable to update Bitbucket repository: %s", $r->{'error'} ] );
		return;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=pod

=for Pod::Coverage after_release

=head1 DESCRIPTION

	# in your profile.ini in the MintingProvider's profile
	[Bitbucket::Update]

This L<Dist::Zilla> plugin updates the information of the Bitbucket repository
when C<dzil release> is run. As of now the following values will be updated:

The 'website' field will be set to the value present in the dist meta via "homepage"
(e.g. the one set by other plugins).

The 'description' field will be set to the value present in $zilla->abstract.

=cut
