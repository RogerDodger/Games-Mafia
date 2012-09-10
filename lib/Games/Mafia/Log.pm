package Games::Mafia::Log;

use strict;
use warnings;

use Carp;
use DateTime;

=head1 NAME

Games::Mafia::Log - Logs for L<Games::Mafia>

=head1 SYNOPSIS

  my $game = Games::Mafia->new;
  my @logs = $game->logs;
  my $log  = $logs[0];
  
  $log->msg;       # 'Game created.'
  $log->time;      # Unix timestamp
  $log->dt;        # DateTime timestamp
  $log->gametime;  # 'Night 1'

=cut

sub new {
	my ($class, %a) = @_;
	
	my $self = bless {
		time => time,
		datetime => DateTime->now,
	}, $class;
	
	$self->{game} = $a{game} if eval { $a{game}->isa('Games::Mafia') } or
		croak "Logs require the Games::Mafia object";
		
	$self->{message}  = $a{message} or croak 'Logs need a message';
	
	$self->{gametime} = $self->{game}->date;
	$self->{type}     = $a{type}    // 'general';
	$self->{private}  = $a{private} // ($self->{game}->{is_day} ? 0 : 1);
	$self->{player}   = $self->{game}->player( $a{player} // 'Nobody' );
	
	$self->{recent}   = $a{recent}  // 1;
	
	return $self;
}

sub msg {
	shift->{message};
}

sub time {
	shift->{time};
}

sub dt {
	shift->{datetime};
}

sub gametime {
	shift->{gametime};
}

1;

=head1 SEE ALSO

L<Games::Mafia>
L<DateTime>

=head1 AUTHOR

Cameron Thornton, E<lt>cthor@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Cameron Thornton.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut