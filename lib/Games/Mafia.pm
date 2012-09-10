package Games::Mafia;

use 5.014002;
use strict;
use warnings;

use Carp;
use Scalar::Util qw/blessed/;
use Games::Mafia::Player;
use Games::Mafia::Tally;
use Games::Mafia::Log;

our $VERSION = '0.02';

=head1 NAME

Games::Mafia - Perl implementation of the mafia party game.

=head1 DESCRIPTION

Creates a game object which can perform the necessary logic for
hosting/running a mafia game.

=head1 SYNOPSIS

  my $game = Games::Mafia->new;
  #blah blah blah

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
		players => {},
		actions => {},
		logs => [],
	}, $class;
	
	$self->{tally} = Games::Mafia::Tally->new($self);
	$self->{players}->{Nobody} = Games::Mafia::Player->new(
		game => $self,
		key  => 'Nobody',
	);
	
	$self->{day_count}      = $a{day_count}     // 1;
	$self->{day_start}      = $a{day_start}     // 0;
	$self->{is_day}         = $a{is_day}        // $self->{day_start};
	$self->{allow_nolynch}  = $a{allow_nolynch} // 1;
	$self->{allow_nokill}   = $a{allow_nokill}  // 1;
	
	$self->log(
		message => "Game created.",
		private => 0,
	);
	
	if(defined $a{players}) {
		for(keys %{$a{players}}) {
			$self->add_player( $_, $a{players}{$_} );
		}
	}	
	
	if(defined $a{votes}) {
		for(keys %{$a{votes}}) {
			$self->add_vote  ( $_, $a{votes}{$_} );
		}
	}
	
	if(defined $a{actions}) {
		for(keys %{$a{actions}}) {
			$self->add_action( $_, $a{votes}{$_} );
		}
	}
	
	return $self;
}

=head2 run

Tick from day to night, or vice versa, performing any lynching or power-role 
actions that are currently queued.

This method should not be given any arguments. Actions and votes should be
queued with the relevant methods beforehand.

The logic of when this method is run should be determined by the operating 
script.

=cut

sub run {
	my $self = shift;
	if(@_) { croak "run takes no arguments." }
	
	return $self if $self->winners;
	
	my $n = $self->electorate;
	
	if($self->{is_day}) {
		$_->lynch for grep { $self->tally->on($_) > $n/2 } $self->players_alive;
	} 
	else {
		$_->kill for grep { $self->tally->on($_) > $n/2 } $self->players_alive;
	}
	$self->tally->reset;
	
	return $self if $self->winners;

	$self->{day_count}++ if $self->{day_start} != $self->{is_day};
	$self->{is_day} = !$self->{is_day};
	
	return $self;
}

=head2 winners

Returns an array of all players whose win condition has been met.

=cut

sub winners {
	my $self = shift;
	
	return grep { $_->is_winner } $self->players_list;
}

=head2 add_player

Adds a player to the game. The player's key may not be 'Nobody'.

  $game->add_player(Player1 => {
    name => 'Alfred',
    role => 'Goon',
  });

The player created is a L<Games::Mafia::Player> object.

All C<add_*> and C<remove_*> methods can add or remove more than one thing at a 
time if given a series of things to add or remove, e.g.:

  $game->add_player(
    Player1 => {
      name => 'Bob',
      role => 'Townie',
    },
    Player2 => {
      name => 'Geoff',
      role => 'Goon',
    },
  );

=cut

sub add_player {
	my $self = shift;
	
	while(@_) {
		my $key  = shift;
		my %a = %{+shift};
		my $role = delete $a{role} or croak "Players must have a role.";
		
		croak "Role '$role' does not exist." unless
			grep { $role eq $_} Games::Mafia::Player->roles;
			
		croak "Player with key '$key' already exists." if 
			grep  { $key eq $_->key } 
			map   { $self->players->{$_} } 
			keys %{ $self->players };
			
		$a{name} //= $key;
		$a{game}   = $self;
		$a{key}    = $key;
		
		$self->players->{$key} = "Games::Mafia::Player::$role"->new(%a);
		$self->players->{$key}->vote('');
		$self->log(
			message => $a{name} . " has joined the game.",
			private => 0,
		);
	}
	
	return $self;
}

=head2 remove_player

  $game->remove_player($john);

Removes a player from the game.

Note: This is different from a player being killed. This method will completely 
remove the player from the game. The player's logs will still be left behind, 
but otherwise all record of the player will be removed from the game.

=cut

sub remove_player {
	my $self = shift;

	while(@_) {
		my $player = $self->player(shift);
			
		delete $self->tally->{votes}{$player->key};
		delete $self->players->{$player->key};
		$self->log( 
			message => $player->name . " has left the game.",
			private => 0,
		);
		undef $player;
	}
	
	return $self;
}

=head2 player

  $game->player('Bobby');

Returns a player's L<Games::Mafia::Player> object.

=cut

sub player {
	my ( $self, $player ) = @_;
	
	return $player if eval { $player->isa('Games::Mafia::Player') };
	return $self->players->{$player} if defined $self->players->{$player};
	
	croak "Cannot resolve a player from '$player'";
}

=head2 players

Returns a hash ref containing all the players in the game.

  $game->players->{Bob};   #Returns Bob's Player object.

=cut

sub players {
	shift->{players};
}

=head2 players_list

Returns an array of all the players in the game, sorted by names (not keys!). 

  #Print the name of all the players in the game
  print $_->name . "\n" for $game->players_list;

=cut

sub players_list {
	my $self = shift;
	
	my @players = 
		map   { $self->players->{$_} } 
		grep  { $_ ne 'Nobody' } 
		keys %{ $self->players };

	return sort { $a->name cmp $b->name } @players;
}

=head2 players_alive

Returns an array of all the living players.

=cut

sub players_alive {
	my $self = shift;
	
	my @players = grep { $_->is_alive } $self->players_list;
	return @players;
}

=head2 players_dead

Returns an array of all the dead players.

=cut

sub players_dead {
	my $self = shift;
	
	my @players = grep { !$_->is_alive } $self->players_list;
	return @players;
}

=head2 players_in

  my @mafia = $game->players_in('Mafia');

Returns an array of all the players in a given team.

=cut

sub players_in {
	my ($self, $team) = @_;
	
	my @players = grep { $_->team eq $team } $self->players_list;
	return @players;
}

=head2 players_alive_in

  my @mafia = $game->players_alive_in('Mafia');
  
Returns an array of all the living players in a given team.

=cut

sub players_alive_in {
	my ($self, $team) = @_;
	
	my @players = grep { $_->team eq $team } $self->players_alive;
	return @players;
}

=head2 add_vote

  $game->add_vote(Voter => 'Voted');

Casts a vote from Voter on to Voted. Voter must be in the list returned
by L<electorate>, and Voted must be in the list returned by L<candidates>. 

=cut

sub add_vote {
	my $self = shift;
	
	while(@_) {
		my $voter = $self->player(shift);
		croak $voter->name . " cannot vote" if !$voter->can_vote;
		
		my $voted = $self->player(shift);
		croak $voted->name . " is not a candidate" if !$voted->is_candidate;
			
		$self->remove_vote($voter) if $voter->vote ne '';
		
		$voter->vote($voted);
		$self->log(
			player  => $voter,
			message => $voter->name . " voted " . $voted->name . ".",
			type    => 'vote',
		);
	}
	
	return $self;
}

=head2 remove_vote

  $game->remove_vote('Player1');

Removes a players vote.

=cut

sub remove_vote {
	my $self = shift;
	
	while(@_) {
		my $voter = $self->player(shift);
		my $voted = $voter->vote;
		return $self if $voted eq ''; #no vote to remove
		
		$voter->vote('');
		$self->log(
			player  => $voter, 
			message => $voter->name . " unvoted " . $voted->name . ".",
			type    => 'vote',
		);
	}
	
	return $self;
}

sub votes {
	my $self = shift;
	
	return $self->{votes};
}

=head2 tally

Returns a L<Games::Mafia::Tally> object with the game's votes.

=cut

sub tally {
	my $self = shift;
	return $self->{tally};
}

=head2 electorate

Returns an array of the players who may vote. At night, this will mostly only be
organised non-town roles (e.g., the Mafia).

=cut

sub electorate {	
	my $self = shift;
	
	my @electorate = grep { $_->can_vote } $self->players_list;
	return @electorate;
}

=head2 candidates

Returns an array of the players who may be voted on.

=cut

sub candidates {
	my $self = shift;
	
	my @candidates = grep { $_->is_candidate } $self->players_list;
	
	#Check if 'Nobody' is a candidate
	push @candidates, $self->player('Nobody') if 
		$self->{allow_nolynch} &&  $self->{is_day} ||
		$self->{allow_nokill}  && !$self->{is_day};

	return @candidates;
}

=head2 add_action

blah blah blah

=cut

sub add_action {
	1;
}

=head2 date

Returns the date in gametime.

  Games::Mafia->new->date; # Returns "Night 1"

=cut

sub date {
	my $self = shift;
	
	return ( $self->{is_day} ? 'Day' : 'Night' ) . ' ' . $self->{day_count};
}

=head2 logs

Returns an array of the game's logs. All logs are L<Games::Mafia::Log> objects.

Optional hash arguments may be provided to filter the results.

  $game->logs(private => 0);      #Grab only public logs
  $game->logs(player  => 'Bob');  #Grab only Bob's logs
  $game->logs(type    => 'vote'); #Grab only vote logs
  $game->logs(recent  => 1);      #Grab only recent logs

C<type> can be any of C<vote death general>.

Recent logs work by showing all logs that haven't been selected as recent logs
before.

=cut

sub logs {
	my($self, %a) = @_;
	
	my @logs = @{ $self->{logs} };
	
	if( defined $a{player} ) {
		$a{player} = $self->player( $a{player} );
		@logs = grep { $_->{player} eq $a{player} } @logs;
	}
	
	@logs = grep { $_->{type}    eq $a{type}    } @logs if defined $a{type};
	@logs = grep { $_->{private} eq $a{private} } @logs if defined $a{private};
	
	if( defined $a{recent} ) {
		@logs = grep { $_->{recent} eq $a{recent} } @logs;
		$_->{recent} = 0 for @logs;
	}
	
	return @logs;
}

sub log {
	my ($self, %a) = @_;
	
	$a{game} = $self;
	push @{ $self->{logs} }, Games::Mafia::Log->new(%a);
	
	return $self;
}

=head1 SEE ALSO

L<Games::Mafia::Player>

=head1 AUTHOR

Cameron Thornton, E<lt>cthor@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Cameron Thornton.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
