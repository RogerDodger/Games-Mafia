use strict;
use warnings;

use Test::More tests => 29;
BEGIN { use_ok('Games::Mafia') };

my $game = Games::Mafia->new(
	allow_nokill => 0,
	day_start => 1,
	players => {
		RogerDodger => {
			role => 'Townie',
		},
		Noname => {
			role => 'Townie',
		},
		Nohead => {
			role => 'Goon',
			life => 0,
		},
		Nolegs => {
			role => 'Goon',
		},
		New => {
			role => 'Townie',
		},
		Novote => {
			role => 'Goon',
		},
		Voteless => {
			role => 'Townie',
		}
	},
	votes => {
		RogerDodger => 'Nolegs',
		Noname => 'Nolegs',
		Nolegs => 'RogerDodger',
		New => 'Nolegs',
	},
);

isa_ok($game, 'Games::Mafia');
isa_ok($game->players->{RogerDodger}, 'Games::Mafia::Player');
is($game->players->{RogerDodger}->role, 'Townie', 'RogerDodger isa Townie');
is($game->logs->{game}->[0][2], 'Game created.', 'Game creation logged');
can_ok($game, qw/add_player players/);
is($game->add_player(Invader_Zim => { role => 'Goon' })->players
	->{Invader_Zim}->role, 'Goon', 'Chained add_player working as intended');
is(grep(/Townie/, Games::Mafia::Player->roles), 1, 'Townie role exists');
is(Games::Mafia->new->date, 'night 1', 'Initial date is "night 1"');
is($game->players->{Nobody}->role, undef, 
	'Player "Nobody" exists under team undef');
is(grep(/Nohead/, keys %{$game->players}), 1, 'Nohead exists');
is(grep(/Nohead/, $game->players_alive), 0, 'Nohead isn\'t alive');
is(grep(/Nohead/, $game->players_dead), 1, 'Nohead is dead');
is($game->players->{Nohead}->{life}, 0, 'Nohead is definitely dead');

my %tally = $game->votes_tally;
is_deeply($tally{RogerDodger}, [qw/Nolegs/], 'Vote tally working');
is_deeply($tally{Nolegs}, [qw/New Noname RogerDodger/], 'Vote tally working');
is_deeply([$game->votes_novoters], [qw/Invader_Zim Novote Voteless/], 
	'Novoters returned as intended');

my $game2 = Games::Mafia->new(allow_nolynch => 0);
is(grep(/Nobody/, $game2->votes_candidates), 1, 'Nokill allowed as intended');
is(grep(/Nobody/, $game->votes_candidates), 1, 
	'Nolynch allowed as intended');
is(grep(/Nobody/, $game->run->votes_candidates), 0, 
	'Nokill disallowed as intended');
is(grep(/Nobody/, $game2->run->votes_candidates), 0, 
	'Nolynch disallowed as intended');
is(($game->run->votes_candidates)[-1], 'Nobody', 
	'"Nobody" at end of given list of candidates');
is($game->run->date, 'night 2', 'Date iteration working as intended');

my $game3 = Games::Mafia->new(players => {
	A => {
		role => 'Townie',
	},
	Z => {
		role => 'Goon',
	},
	Q => {
		role => 'Townie',
	},
	Y => {
		role => 'Townie',
		life => 0,
	},
});
is_deeply([$game3->players_list], [qw/A Q Y Z/], 
	'players_list returned and ordered as intended');
is_deeply([$game3->players_alive], [qw/A Q Z/], 
	'players_alive returned and ordered as intended');
$game3->add_vote(Z => 'Q', Z => 'A');
my $z = $game3->logs->{players}->{Z}->{votes};
is_deeply([$z->[1][2], $z->[2][2]], ['Z unvoted Q.', 'Z voted on A.'],
	'Unvote/revote logging working as intended');
ok(ref (my $y = $game3->remove_player(qw/Y Q/)->logs->{game}), 
	'Player removal chaining working as intended');
is_deeply([$y->[-1][2], $y->[-2][2]], 
	['Q has left the game.', 'Y has left the game.'], 
	'Players Q and Y removal logged');
ok(!(exists $game3->votes->{Q} || exists $game3->players->{Q} ||
exists $game3->votes->{Y} || exists $game3->players->{Y}),
	'Q and Y properly deleted from game');