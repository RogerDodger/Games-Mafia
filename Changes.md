0.02
====
- Lots of logic refractored to ask Player objects what the result is, such that different roles can change the result without the Games::Mafia object needing to be made aware
  - In other words, Player logic being put into the Player object
- Logs refractored to use an object and a single list
  - Filterable based on tag properties
- Player capture encapsulated to work for both keys and objects
- Tally object for tallying votes
  - Not sure if necessary, considering removal
- More tests
- Readme updated

0.01
====
- Created *Wed Jun 27 12:03:48 2012*
