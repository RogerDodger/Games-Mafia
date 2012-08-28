package Games::Mafia::Player;

use Carp;

my @roles = qw/Goon Townie/;
for(@roles) {
	eval("use Games::Mafia::Player::$_");
	die "Games::Mafia::Player::$_ failed to load: $@" if $@;
}

sub new {
	my $class = shift;
	my %a = @_;
	my $self = bless {}, $class;
	
	if(defined $a{role}) {
		carp "Role should be assigned by using the correct subclass." if $^W;
		my $role = delete $a{role};
		return "Games::Mafia::Player::$role"->new(%a);
	}
	
	$self->{life} = $a{life} // 1;
	$self->{name} = $a{name} or croak "Players must have a name.";
	
	return $self;
}

sub roles { @roles }
sub act { croak $self->role. " has no action." }

sub role { undef }
sub role_lynched { shift->role }
sub role_killed { shift->role }

sub team { undef }
sub team_scouted { shift->team }

sub lynch {
	my($self, $game) = @_;
	if(!ref $self or !ref $game) {croak "Game and self must be instances." }
	
	$self->{life} = 0;
	$game->_log($game->logs->{game}, 
		$self->{name} . " (" . $self->role_lynched . ") has been lynched.");
	
	return 1;
}

sub kill {
	my($self, $game) = @_;
	if(!ref $self || !ref $game) {croak "Game and self must be instances" }
	
	$self->{life} = 0;
	$game->_log($game->logs->{game},
		$self->{name} . " (" . $self->role_killed . ") has been killed.");
	
	return 1;
}

sub is_alive {
	my $self = shift;
	if (!ref $self) { croak "is_alive must be performed on an instance." }
	
	return 1 if $self->{life} > 0;
	return;
}

=head1 SEE ALSO

L<Games::Mafia>

=head1 AUTHOR

Cameron Thornton, E<lt>cthor@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2012 by Cameron Thornton.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;