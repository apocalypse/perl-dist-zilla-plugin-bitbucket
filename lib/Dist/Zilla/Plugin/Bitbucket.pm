package Dist::Zilla::Plugin::Bitbucket;

# ABSTRACT: Plugins to integrate Dist::Zilla with Bitbucket

1;

=pod

=head1 SYNOPSIS

	[Bitbucket::Create]
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

=head1 ACKNOWLEDGEMENTS

This dist was shamelessly copied from ALEXBIO's excellent L<Dist::Zilla::Plugin::GitHub> :)

I didn't implement the PluginBundle nor the Command::gh modules as I didn't have a need for them. Please
let me know if you want them!

=cut
