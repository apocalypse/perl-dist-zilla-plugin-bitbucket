package Config::Identity::Bitbucket;

# ABSTRACT: Manages the login and password for Bitbucket.org

# ROKR++ I copied this from Config::Identity::GitHub
use Config::Identity 0.0018;
use Carp qw( croak );

our $STUB = 'bitbucket';
sub STUB { defined $_ and return $_ for $ENV{CI_BITBUCKET_STUB}, $STUB }

sub load {
	my $self = shift;
	return Config::Identity->try_best( $self->STUB );
}

sub check {
	my $self = shift;
	my %identity = @_;
	my @missing;
	defined $identity{$_} && length $identity{$_} or push @missing, $_ for qw/ login password /;
	croak( "Missing ", join ' and ', @missing ) if @missing;
}

sub load_check {
	my $self = shift;
	my %identity = $self->load;
	$self->check( %identity );
	return %identity;
}

1;

=pod

=for Pod::Coverage STUB check load load_check

=head1 SYNOPSIS

	use Config::Identity::Bitbucket;
	my %identity = Config::Identity::Bitbucket->load;
	print "login: $identity{login} password: $identity{password}\n";

=head1 DESCRIPTION

This module is meant to be used as part of the L<Config::Identity> framework. Please refer to it for further details.

=cut
