package Games::Mafia::Player;

use strict;
use warnings;

use Carp;

my @roles = qw/Goon Townie/;
for(@roles) {
	local $@ = '';
	eval("use Games::Mafia::Player::$_");
	die "Games::Mafia::Player::$_ failed to load: $@" if $@;
}

sub new {
	my ($class, %a) = @_;
	my $self = bless {}, $class;
	
	$self->{life} = $a{life} // 1;
	$self->{game} = $a{game} or croak "Players must be in a game.";
	$self->{key}  = $a{key}  or croak "Players must have a key.";
	$self->{name} = $a{name} // $self->{key};
	
	return $self;
}

sub roles {
	@roles;
}

sub act {
	croak shift->role . " has no action.";
}
sub can_act {
	0;
}

sub vote {
	my $self = shift;
	return $self->{game}->tally->{votes}->{ $self->key } = shift if @_;
	return $self->{game}->tally->{votes}->{ $self->key };
}
sub logs {
	my $self = shift;
	return $self->{game}->logs(player => $self);
}
sub can_vote {
	0;
}
sub is_candidate {
	shift->is_alive;
}

sub name {
	return shift->{name};
}
sub key {
	return shift->{key};
}

sub role { 
	undef;
}
sub role_lynched { 
	shift->role;
}
sub role_killed { 
	shift->role;
}

sub team {
	undef;
}
sub team_scouted {
	shift->team;
}

sub lynch {
	my $self = shift;
	
	return $self if !$self->is_alive;
	
	$self->{life}--;
	$self->{game}->log(
		player  => $self,
		message => $self->name . " (" . $self->role_lynched . ") has been lynched.",
		type    => 'death',
		private => 0,
	) if !$self->is_alive;
	
	return $self;
}

sub kill {
	my $self = shift;
	
	return $self if !$self->is_alive;
	
	$self->{life}--;
	$self->{game}->log(
		player  => $self,
		message => $self->name . " (" . $self->role_lynched . ") has been killed.",
		type    => 'death',
		private => 0,
	) if !$self->is_alive;
	
	return $self;
}

sub is_alive {
	my $self = shift;
	
	return 1 if $self->{life} > 0;
	0;
}

sub is_winner {	
	0;
}

1;

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