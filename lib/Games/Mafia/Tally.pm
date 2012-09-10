package Games::Mafia::Tally;

use strict;
use warnings;
use Scalar::Util qw/blessed/;

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->{game}  = shift;
	$self->{index} = 0;
	
	return $self;
}

sub reset {
	my $self = shift;
	delete $self->{votes};
	$self->{votes}{ $_->key } = '' for $self->{game}->players;
}

=head2 on 

  $tally->on($joe);

Returns a list of players who have voted on a given player.

=cut

sub on {
	my $self = shift;
	my $player = $self->{game}->player(shift);
	
	return grep { $player eq $_->vote } $self->{game}->electorate;
}

=head2 voters

Returns a list of the players who have cast a vote.

=cut

sub voters {
	my $self = shift;
	return grep { $_->vote ne '' } $self->{game}->electorate;
}

=head2 novoters

Returns a list of the players who may cast a vote, but haven't.

=cut

sub novoters {
	my $self = shift;
	return grep { $_->vote eq '' } $self->{game}->electorate;
}

=head1 SEE ALSO

L<Games::Mafia>

=head1 AUTHOR

Cameron Thornton, E<lt>cthor@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Cameron Thornton.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;