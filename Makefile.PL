use 5.014002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Games::Mafia',
    VERSION_FROM      => 'lib/Games/Mafia.pm', # finds $VERSION
    PREREQ_PM         => {
		DateTime => 0,
		Carp => 0,
	},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Games/Mafia.pm', # retrieve abstract from module
       AUTHOR         => 'Cameron Thornton <cthor@cpan.org>') : ()),
);
