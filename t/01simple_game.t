use strict;
use warnings;

use Test::More;
BEGIN { use_ok('Games::Mafia') };

#Testing a simple game, i.e., game without power roles.

my $game = Games::Mafia->new(
	players => {
		A => { role => 'Townie' },
		B => { role => 'Townie' },
		C => { role => 'Townie' },
		D => { role => 'Townie' },
		E => { role => 'Townie' },
		F => { role => 'Townie' },
		Y => { role => 'Goon' },
		Z => { role => 'Goon' },
	},
);

is($game->date, 'night 1', 'Game starts on night 1');
is($game->logs->{game}->[0][2], 'Game created.', 'Game creation logged.');
ok($game->players_alive == 8, '8 players remain');
is_deeply([$game->votes_electorate], [qw/Y Z/], 'Only mafia can vote at night');
is_deeply([$game->votes_candidates], ['A'..'F', qw/Y Z Nobody/],
	'Candidates as expected');
$game->add_vote(Y => 'A', Z => 'A');
is($game->votes->{Z}, 'A', "Z's vote correctly added");
is($game->logs->{players}->{Z}->{votes}->[0][2], 
	'Z voted on A.', "Z's vote correctly logged");

	#End Night 1
is($game->run->votes->{Z}, '', 'Votes cleared after night ticks');

ok(!$game->players->{A}->is_alive, 'A is dead');
ok($game->players_alive == 7, '7 players remain');
is($game->logs->{game}->[-1][2], 'A (Townie) has been lynched.', 
	'Lynch logged as intended');
is_deeply([$game->players_in('Mafia')], [qw/Y Z/], "Y and Z are in 'Mafia'");
is_deeply([$game->votes_electorate], ['B'..'F', qw/Y Z/], 'Electorate as expected');
$game->add_vote(B => 'C', F => 'C', Z => 'C', Y => 'C', C => 'B');

	#End Day 1
is($game->run->votes->{C}, '', 'Votes cleared after day ticks');

is_deeply([$game->players_alive], ['B', qw/D E F Y Z/], "Living players as expected");
ok(!$game->players->{C}->is_alive, 'C is dead');
$game->add_vote(Y => 'B', Z => 'B');

done_testing;