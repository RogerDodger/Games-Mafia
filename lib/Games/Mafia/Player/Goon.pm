package Games::Mafia::Player::Goon;

use base 'Games::Mafia::Player';

sub team {
	"Mafia";
}
sub role {
	"Goon";
}
sub is_winner {
	my $self = shift;
	my $game = $self->{game};
	
	return 1 if $game->players_alive_in('Mafia') >= $game->players_alive / 2;
	0;
}
sub can_vote {
	shift->is_alive;
}

1;