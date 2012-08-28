package Games::Mafia;

use 5.014002;
use strict;
use warnings;

use Carp;
use Games::Mafia::Player;

our $VERSION = '0.01';

=head1 NAME

Games::Mafia - Perl implementation of the mafia party game.

=head1 DESCRIPTION

Creates a game object which can perform the necessary logic for
hosting/running a mafia game.

=head1 ATTRIBUTES

The following attributes may be passed to the constructor.

=head2 day_count

Integer for the day counter. Defaults to 1.

=head2 day_start

Bool for if the game started at day. Defaults to 0.

=head2 is_day

Bool for if the game state is currently day. Defaults to C<day_start>.

=head2 allow_nolynch

Bool for if votes on 'Nobody' are allowed during the day. Defaults to 1.

'Nobody' cannot be killed, so votes on him/her will do nothing, but the option 
to vote on a dummy is useful when players wish to pass the day/night without
killing/lynching someone.

=head2 allow_nokill

Bool for if votes on 'Nobody' are allowed during the night. Defaults to 1.

=head1 METHODS

Unless stated otherwise, methods will return the Games::Mafia object -- useful
for chaining.

=head2 new

Constructor. Values for keys C<players>, C<votes>, and C<actions> will be given
to the respective C<add_> methods.

  my $game = Games::Mafia->new(
    day_count     => 1,
    day_start     => 1,

    players => {
      Player1 => {role => 'Townie'},
      Player2 => {role => 'Goon'},
    },
    votes => {
      Player1 => 'Player2',
      Player2 => 'Player1',
    },
  );

=cut

sub new {
	my $class = shift;
	my %a = @_;
	my $self = bless {
		players => {
			Nobody => Games::Mafia::Player->new(name => 'Nobody'),
		},
		votes => {},
		actions => {},
		logs => {
			game => [],
			players => {},
		},
	}, $class;
	
	$self->{day_count}      = $a{day_count}     // 1;
	$self->{day_start}      = $a{day_start}     // 0;
	$self->{is_day}         = $a{is_day}        // $self->{day_start};
	$self->{allow_nolynch}  = $a{allow_nolynch} // 1;
	$self->{allow_nokill}   = $a{allow_nokill}  // 1;
	
	$self->_log($self->logs->{game}, "Game created.");
	
	if(defined $a{players}) {
		for(keys %{$a{players}}) {
			$self->add_player($_, $a{players}->{$_});
		}
	}	
	
	if(defined $a{votes}) {
		for(keys %{$a{votes}}) {
			$self->add_vote($_, $a{votes}->{$_});
		}
	}
	
	if(defined $a{actions}) {
		for(keys %{$a{actions}}) {
			$self->add_action($_, $a{votes}->{$_});
		}
	}
	
	return $self;
}

=head2 run()

Tick from day to night, or vice versa, performing any lynching or power-role 
actions that are currently queued.

This method should not be given any arguments. Actions and votes should be
queued with the relevant methods beforehand.

The logic of when this method is run should be determined by the operating 
script.

=cut

sub run {
	my $self = shift;
	if(@_)         { croak "run takes no arguments." }
	if(!ref $self) { croak "run must be performed on an instance." }
	
	return $self if defined $self->{winners};
	
	#blah blah blah
	
	my $n = $self->votes_electorate;
	my %tally = $self->votes_tally;
	
	if($self->{is_day}) {
		$self->players->{$_}->lynch($self) for 
			grep {@{$tally{$_}} > $n/2} keys %tally;
	} 
	else {
		$self->players->{$_}->kill($self) for 
			grep {@{$tally{$_}} > $n/2} keys %tally;
	}
	
	
	$self->votes->{$_} = '' for keys %{$self->votes};
	#   Check if game is ended and define winners; else increment day with
	#  appropriate logic
	my @mafia = $self->players_in('Mafia');
	if(@mafia == 0) {
		$self->{winners} = $self->players_in('Town');
	}
	elsif(@mafia >= $self->players_alive/2) {
		$self->{winners} = [@mafia];
	} 
	else {
		$self->{day_count}++ if $self->{day_start} != $self->{is_day};
		$self->{is_day} = $self->{is_day} ? 0 : 1;
	}
	
	return $self;
}

=head2 C<add_player($playername, \%attr)>

Adds a player to the game. The player's name may not be 'Nobody'.

  $game->add_player(Player1 => {
    role => $role,
  });

The player created is a Games::Mafia::Player::$role object (see
L<Games::Mafia::Player>).

All C<add_*> and C<remove_*> methods can add or remove more than one thing at a 
time if given a series of things to add or remove, e.g.:

  $game->add_player(
    Player1 => {
      role => 'Townie',
    },
    Player2 => {
      role => 'Goon',
    },
  );

=cut

sub add_player {
	my $self = shift;
	if(!ref $self) { croak "add_player must be performed on an instance." }
	
	while(@_) {
		my $player = shift;
		croak "You can't call a player 'Nobody'" if $player eq 'Nobody';
		my %a = %{+shift} or croak 'add_player needs an even number of args';
		my $role = delete $a{role} or croak "Players must have a role.";
		croak "Role '$role' does not exist or is not loaded. Print Games::Mafi".
			"a::Player->roles to see the list of loaded/available roles." unless
			grep {$role eq $_} Games::Mafia::Player->roles;		
		croak "Player '$player' already exists." if 
			exists $self->players->{$player};
		$a{name} = $player;
		
		$self->players->{$player} = "Games::Mafia::Player::$role"->new(%a);
		$self->votes->{$player} = '';
		$self->_log($self->logs->{game}, "$player has joined the game.");
		$self->logs->{players}->{$player} = {};
		$self->logs->{players}->{$player}->{votes} = [];
		$self->logs->{players}->{$player}->{actions} = [];
	}
	
	return $self;
}

=head2 remove_player($player)

Removes C<$player> from the game. C<$player> should be the player's name, not
their Player object.

Note: This is different from a player being killed. This method will completely 
remove the player from the game. The player's logs will still be left behind, 
but otherwise all record of the player will be removed from the game.

=cut

sub remove_player {
	my $self = shift;
	if(!ref $self) { croak "remove_player must be performed on an instance." }

	while(@_) {
		my $player = shift;
		croak "remove_player takes player names, not player objects." 
			if ref $player;
		croak "Player '$player' does not exist." unless 
			grep {$player eq $_} $self->players_list;
			
		delete $self->players->{$player};
		delete $self->votes->{$player};
		$self->_log($self->logs->{game}, "$player has left the game.");
	}
	
	return $self;
}

=head2 players()

Returns a hash ref containing all the players in the game, where the keys are 
the players' names and the values are Player objects.

  $game->players->{Bob}    #Returns Bob's Player object.

=cut

sub players {
	my $self = shift;
	if(!ref $self) { croak "players must be performed on an instance." }
	
	return $self->{players};
}

=head2 players_list()

Returns an array of all the players in the game. 

Note: This and all other C<players_*> methods are distinct from C<players>, as
they return an array of names, not a hash ref, and they exclude the special
'Nobody' player.

=cut

sub players_list {
	my $self = shift;
	if(!ref $self) { croak "players_list must be performed on an instance." }
	
	my @players = grep {$_ ne 'Nobody'} keys %{$self->players};
	return sort {$a cmp $b} @players;
}

=head2 players_alive()

Returns an array of all the living players.

=cut

sub players_alive {
	my $self = shift;
	if(!ref $self) { croak "players_alive must be performed on an instance." }
	
	my @players = grep {$self->players->{$_}->is_alive} $self->players_list;
	return @players;
}

=head2 players_dead()

Returns an array of all the dead players.

=cut

sub players_dead {
	my $self = shift;
	if(!ref $self) { croak "players_dead must be performed on an instance." }
	
	my @players = grep {!$self->players->{$_}->is_alive} $self->players_list;
	return @players;
}

=head2 C<players_in($team)>

Returns an array of all players in C<$team>.

=cut

sub players_in {
	my $self = shift;
	if(!ref $self) { croak "players_in must be performed on an instance." }
	my $team = shift;
	
	my @players = grep {$self->players->{$_}->team eq $team} $self->players_list;
	return @players;
}

=head2 C<add_vote($voter, $voted)>

  $game->add_vote(Player1 => 'Player2');

Casts a vote from C<$voter> on to C<$voted>. C<$voter> must be in the list 
returned by C<votes_electorate>, and C<$voted> must be in the list returned by
C<votes_candidates>. 

If it exists, removes C<$voter>'s current vote with C<remove_vote> before
casting the vote. 

=cut

sub add_vote {
	my $self = shift;
	if(!ref $self) { croak "add_vote must be performed on an instance." }
	
	while(@_) {
		my $voter = shift;
		croak "$voter cannot vote." unless 
			grep {$_ eq $voter} $self->votes_electorate;
		
		my $voted = shift or croak 'add_vote needs an even number of args';
		croak "$voted is not a valid candidate" unless
			grep {$_ eq $voted} $self->votes_candidates;
		
		if($self->{votes}->{$voter} ne '') {  
			#Voter already has a vote. Call remove_vote for accurate logs.
			$self->remove_vote($voter);
		}
		
		$self->{votes}->{$voter} = $voted;
		$self->_log($self->logs->{players}->{$voter}->{votes}, 
			"$voter voted on $voted.");
	}
	
	return $self;
}

=head2 remove_vote($voter)

Resets C<$voter>'s vote to the empty string.

=cut

sub remove_vote {
	my $self = shift;
	if(!ref $self) { croak "remove_vote must be performed on an instance." }
	
	while(@_) {
		my $voter = shift;
		croak "'$voter' does not exist" unless exists $self->players->{$voter};
		
		my $voted = $self->votes->{$voter};
		return $self if $voted eq ''; #no vote to remove
		
		$self->votes->{$voter} = '';
		$self->_log($self->logs->{players}->{$voter}->{votes},
			"$voter unvoted $voted.");
	}
	
	return $self;
}

=head2 votes()

Returns a hash ref of the current votes, where the keys are players and values
are whom they've voted for. Votes are defaulted to the empty string.

  $game->votes->{Bob} #Returns whom Bob has voted on -- '' if there is no vote.

=cut

sub votes {
	my $self = shift;
	if(!ref $self) { croak "votes must be performed on an instance." }
	
	return $self->{votes};
}

=head2 votes_electorate()

Returns an array of the players who may vote. At night, this will mostly only be
organised non-town roles (e.g., the Mafia).

=cut

sub votes_electorate {	
	my $self = shift;
	if(!ref $self) { croak "votes_electorate must be performed on an instance."}
	
	my @electorate;
	
	for($self->players_alive) {
		my $player = $self->players->{$_};
		
		push @electorate, $_ if 
			$self->{is_day} || #Everyone can vote during the day
			$player->team eq 'Mafia' && $player->role ne 'Traitor';
	}
	
	return @electorate;
}

=head2 votes_candidates()

Returns an array of the players who may be voted on.

=cut

sub votes_candidates {
	my $self = shift;
	if(!ref $self) { croak "votes_candidates must be performed on an instance."}
	
	my @candidates = $self->players_alive;
	
	#Check if 'Nobody' is a candidate
	push @candidates, 'Nobody' if 
		$self->{allow_nolynch} &&  $self->{is_day} ||
		$self->{allow_nokill}  && !$self->{is_day};

	return @candidates;
}

=head2 votes_tally()

Returns a tally of the votes as a hash, where the keys are who has been voted
on, and the values are array refs of who has voted on that player.

The utility method C<votes_tally_keys> returns the keys of the hash sorted by
how many votes the players have on them in descending order.

  my %tally = $game->votes_tally;
  for($game->votes_tally_keys) {
    my @voters = @{$tally{$_}};
    print "$_ has been voted on by " . join(", ", @voters) . "\n";
  }

=cut

sub votes_tally {
	my $self = shift;
	if(!ref $self) { croak "votes_tally must be performed on an instance." }
	
	my %tally;
	for($self->votes_electorate) {
		my $vote = $self->votes->{$_};
		next if $vote eq '';
		$tally{$vote} = $tally{$vote} // [];
		push @{$tally{$vote}}, $_;
	}
	
	return %tally;
}

sub votes_tally_keys {
	my $self = shift;
	if(!ref $self) { croak "votes_tally_keys must be performed on an instance."}
	
	my %t = $self->votes_tally;
	my @keys = sort { @{$t{$b}} <=> @{$t{$a}} } keys %t;
	
	return @keys;
}

=head2 votes_novoters()

Returns an array of the players who can vote, but haven't.

=cut

sub votes_novoters {
	my $self = shift;
	if(!ref $self) { croak "votes_novoters must be performed on an instance." }

	my @novoters;
	for($self->votes_electorate) {
		push @novoters, $_ if $self->votes->{$_} eq '';
	}
	
	return @novoters;
}

=head2 add_action()

blah blah blah

=cut

sub add_action {
	1;
}

=head2 date()

Returns the date in gametime, which is either 'day ' or 'night ' followed by the
day counter.

  Games::Mafia->new->date; # Returns "night 1"

=cut

sub date {
	my $self = shift;
	if(!ref $self) { croak "date must be performed on an instance." }
	
	return ($self->{is_day}?'day':'night').' '.$self->{day_count};
}

=head2 logs()

Returns a hash ref of the game logs.

The top-level of the log hash contains two keys: C<game> and C<players>. 

The value of C<{game}> is an array ref of general game logs that should be 
public to everyone, such as player deaths, role flips, players being 
added or removed from the game, and day/night toggles.

The value of C<{players}> is a hash ref with a key for each player in the game. 
The value of each of those is another hash ref with two keys: C<votes> and
C<actions>. The value of C<{votes}> is an array ref of the player's voting 
history, and the value of C<{actions}> is an array ref of the player's action
history.

  my @Bobs_votes = @{$game->logs->{players}->{Bob}->{votes}};
  my @game_logs  = @{$game->logs->{game}};

All log entries are three-element array refs: C<[time, $game-E<gt>date, $log]> 
(i.e., logs are timestamped with both gametime and realtime).

=cut

sub logs {
	my $self = shift;
	if(!ref $self) { croak "logs must be performed on an instance." }
	
	return $self->{logs};
}

sub _log {
	# Undocumented ("internal") function to make logging neater/encapsulated.
	# @args:
	#    array ref of log list to be added to
	#    log msg to be logged
	my ($self, $log, $msg) = @_;
	if(!ref $self) { croak "_log must be performed on an instance." }
	if(!ref $log ) { croak "1st arg must be array ref to logs."}
	
	push @$log, [time, $self->date, $msg];
	
	return $self;
}

=head1 SEE ALSO

L<Games::Mafia::Player>

L<http://en.wikipedia.org/wiki/Mafia_(party_game)>,
L<http://www.epicmafia.com/role>, and/or L<http://wiki.mafiascum.net/> for the
general rules of the game.

=head1 AUTHOR

Cameron Thornton, E<lt>cthor@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2012 by Cameron Thornton.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
