use strict;
use warnings;

use Test::More;
BEGIN { use_ok('Games::Mafia') };

my $game = Games::Mafia->new(
	allow_nokill => 0,
	day_start => 1,
	players => {
		RogerDodger => { role => 'Townie' },
		Noname =>      { role => 'Townie' },
		New =>         { role => 'Townie' },
		Voteless =>    { role => 'Townie' },
		Nolegs =>      { role => 'Goon' },
		Novote =>      { role => 'Goon' },
		Nohead => {
			role => 'Goon',
			life => 0,
		},
	},
	votes => {
		RogerDodger => 'Nolegs',
		Noname => 'Nolegs',
		Nolegs => 'RogerDodger',
		New => 'Nolegs',
	},
);

isa_ok( $game, 'Games::Mafia' );
isa_ok( $game->players->{RogerDodger}, 'Games::Mafia::Player' );

is(
	$game->players->{RogerDodger}->role,
	'Townie', 
	'RogerDodger isa Townie'
);
is_deeply(
	[ ($game->logs(player => 'Nobody', recent => 1))[0]->msg ],
	[ 'Game created.' ],
	'Game creation logged.',
);
is( 
	$game->add_player( Invader_Zim => { role => 'Goon' } )
		->players->{Invader_Zim}->role, 
	'Goon', 
	'Chained add_player working as intended',
);
is(
	Games::Mafia->new->date, 
	'Night 1', 
	'Initial date is "night 1"',
);
is( 
	$game->players->{Nobody}->role,
	undef, 
	'Player "Nobody" exists under team undef'
);
	
ok(
	(grep /Townie/, Games::Mafia::Player->roles), 
	'Townie role exists',
);
ok(
	(grep /Nohead/, keys $game->players), 
	'Nohead exists',
);
ok(
	!(grep {$_->name eq 'Nohead'} $game->players_alive),
	"Nohead isn't alive",
);
ok(
	(grep {$_->name eq 'Nohead'} $game->players_dead),
	'Nohead is dead',
);
ok(
	!$game->players->{Nohead}->is_alive,
	'Nohead is definitely dead',
);

is_deeply(
	[ $game->tally->on('RogerDodger') ], 
	[ map { $game->player($_) } qw/Nolegs/ ], 
	'Vote tally working',
);
is_deeply(
	[ $game->tally->on('Nolegs') ], 
	[ map { $game->player($_) } qw/New Noname RogerDodger/ ], 
	'Vote tally working',
);
is_deeply(
	[map {$_->name} $game->tally->novoters], 
	[qw/Invader_Zim Novote Voteless/], 
	'Novoters returned as intended',
);

my $game2 = Games::Mafia->new(allow_nolynch => 0);
ok( 
	(grep /Nobody/, map { $_->key } $game2->candidates), 
	'Nokill allowed as intended',
);
ok(
	(grep /Nobody/, map { $_->key } $game->candidates),
	'Nolynch allowed as intended',
);
ok(
	!(grep /Nobody/, map { $_->key } $game->run->candidates),
	'Nokill disallowed as intended',
);
ok( 
	!(grep /Nobody/, map { $_->key } $game2->run->candidates),
	'Nolynch disallowed as intended',
);

is(
	($game->run->candidates)[-1],
	$game->player('Nobody'), 
	'"Nobody" at end of given list of candidates'
);
is(
	$game->run->date,
	'Night 2', 
	'Date iteration working as intended'
);

my $game3 = Games::Mafia->new(players => {
	A => { role => 'Townie' },
	Z => { role => 'Goon' },
	Q => { role => 'Townie' },
	Y => {
		role => 'Townie',
		life => 0,
	},
});
is_deeply(
	[ map { $_->key } $game3->players_list ],
	[ qw/A Q Y Z/ ],
	'players_list returned and ordered as intended'
);
is_deeply(
	[ map { $_->key } $game3->players_alive ],
	[ qw/A Q Z/ ], 
	'players_alive returned and ordered as intended'
);

$game3->logs(recent => 1);
$game3->add_vote(Z => 'Q', Z => 'A');
is_deeply(
	[ map { $_->msg } $game3->logs(recent => 1) ], 
	[ 'Z voted Q.', 'Z unvoted Q.', 'Z voted A.' ],
	'Unvote/revote logging working as intended'
);
is_deeply(
	[ map { $_->msg } $game3->remove_player(qw/Y Q/)->logs(recent => 1) ], 
	[ map { "$_ has left the game." } qw/Y Q/ ],
	'Player removal logged',
);
is(
	($game3->logs)[0]->dt->year,
	(gmtime)[5] + 1900,
	'DateTime module installed',
);
ok(
	!( grep { exists $game3->tally->{votes}{$_} || 
		eval( '$game3->player($_)' ) } qw/Q Y/ ),
	'Q and Y properly deleted from game',
);

done_testing;