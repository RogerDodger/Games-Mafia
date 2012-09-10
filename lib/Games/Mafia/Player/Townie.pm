package Games::Mafia::Player::Townie;

use base 'Games::Mafia::Player';

sub team {
	"Town";
}
sub role { 
	"Townie";
}
sub is_winner {
	my $self = shift;
	
	return 1 if $self->{game}->players_alive_in('Mafia') == 0;
	0;
}
sub can_vote {
	my $self = shift;
	$self->{game}->{is_day} && $self->is_alive;
}

1;