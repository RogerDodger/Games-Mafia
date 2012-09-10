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
		Y => { 
			role => 'Goon',
			name => 'Yellow',
		},
		Z => { role => 'Goon' },
	},
);

is(
	$game->date, 
	'Night 1',
	'Game starts on Night 1',
);
is(
	$game->logs(player => 'Nobody', recent => 1)->[0]->msg,
	'Game created.',
	'Game creation logged.',
);
ok(
	$game->players_alive == 8,
	'8 players remain',
);
is_deeply(
	[ map { $_->name } $game->electorate ], 
	[ qw/Yellow Z/ ], 
	'Only mafia can vote at night',
);
is_deeply(
	[ map { $_->key } $game->candidates ], 
	[ 'A'..'F', qw/Y Z Nobody/ ],
	'Candidates as expected',
);
is(
	$game->add_vote(Y => 'A', Z => 'A')->player('Z')->vote, 
	$game->player('A'), 
	"Z's vote correctly added",
);
is_deeply(
	[ map { $_->msg } $game->logs(recent => 1, private => 1) ],
	[ 'Yellow voted A.', 'Z voted A.' ],
	"Z's vote correctly logged",
);

#End Night 1
$game->run;
#Begin Day 1

is_deeply(
	[ map { $_->vote } $game->players_alive ], 
	[ map { '' } $game->players_alive ], 
	'Votes cleared after night ticks',
);
ok(
	!$game->player('A')->is_alive,
	'A is dead',
);
ok(
	$game->players_alive == 7,
	'7 players remain',
);
is_deeply(
	[ map { $_->msg } $game->logs(type => 'death', recent => 1) ],
	[ 'A (Townie) has been killed.' ], 
	'Kill logged as intended',
);
is_deeply(
	[ map { $_->name } $game->players_in('Mafia') ],
	[ qw/Yellow Z/ ], 
	"Y and Z are in Mafia",
);
is_deeply(
	[ map { $_->key } $game->electorate ],
	['B'..'F', qw/Y Z/],
	'Electorate as expected',
);

$game->add_vote(
	B => 'C',
	F => 'C',
	Z => 'C',
	Y => 'C',
	C => 'B',
);

is_deeply(
	[ map { $_->msg } $game->logs(recent => 1) ],
	[ ( map { "$_ voted C." } qw/B F Z Yellow/ ), 'C voted B.' ],
	'Votes recorded as intended',
);
#End Day 1
$game->run;
#Begin Night 2

is(
	$game->player('C')->vote, 
	'', 
	'Votes cleared after day ticks',
);
is_deeply(
	[ map { $_->key } $game->players_alive ], 
	[ qw/B D E F Y Z/ ], 
	"Living players as expected",
);
ok(
	!$game->player('C')->is_alive,
	'C is dead'
);
is_deeply(
	[ map { $_->msg } $game->logs(recent => 1) ],
	[ 'C (Townie) has been lynched.' ], 
	'Lynch logged as intended',
);
is_deeply(
	[ map { $_->key } $game->players_alive_in('Town') ],
	[ qw/B D E F/ ],
	"Living players in town as expected",
);
is_deeply(
	[ map { $_->key } $game->players_alive_in('Mafia') ],
	[ qw/Y Z/ ],
	"Living players in mafia as expected",
);

#End Night 2
$game->add_vote(Y => 'B', Z => 'B');
$game->logs(recent => 1);
$game->run;
#Begin Day 2

is_deeply(
	[ map { $_->msg } $game->logs(recent => 1) ],
	[ 'B (Townie) has been killed.' ],
	"B's death logged as intended",
);
is(
	$game->date,
	'Day 2',
	"It is now Day 2",
);
ok(
	$game->players_alive == 5,
	"5 players remain",
);

done_testing;