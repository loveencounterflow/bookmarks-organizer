

# Bookmarks Organizer

## Installation

### Dependencies

#### PostGreSQL

```sh
sudo apt install postgresql-server-dev-10
sudo apt install postgresql-plpython3-10
sudo apt install postgresql-contrib-10
# sudo apt install postgresql-10-pgtap
sudo apt install postgresql-10-plsh
# sudo apt install postgresql-9.6-plv8
# sudo apt install postgresql-plperl-9.6
```

#### Python

```sh
sudo pip install pipenv
pipenv install tap.py pytest
```

### Running Tests

```sh
py.test --tap-files
```

# The FlowMatic Finite Automaton

## Symbolic and Built-In States


* `FIRST`—the point of a `RESET` act; must be the 'point of origin' in the transition table.

* `LAST`—

* `*`—a.k.a. 'star' or 'catchall tail'; a transition with a catchall tail will
  match any point, even a non-existing one when the journal is empty after after
  initialization and can thus be used to bootstrap the FA.

* `...`—a.k.a. 'ellipsis', 'anonymous', 'continuation' or 'continue'; may occur
  as point (where it signifies 'continue with next transition' in order of
  inseetion to transitions table) or as tail (where it means 'continued from
  previous transition').

## Symbolic and Built-In Acts


* `RESET`—to be called as the first act after setup; initializes journal (but
  not the board).

* `START`—to be called as the first act of a new case.

* `STOP`-to be called as the last act of a case.

* `->`—a.k.a. 'walkthrough', 'then' or 'auto-act'; indicates that the
  assciatiated command is to be executed without waiting for the next act. This
  allows to write sequences of commands.

## Constraints on Transitions Table

* All tuples `( tail, act )` must be unique; there can only be at most one
  transition to follow when the current state is paired with the upcoming act.
  The exception is the tuple `( '...', '->' )`, which may occur any number of
  times.

* A '*' (star) in the tail of a transition makes the associated act unique; IOW,
  a starred act can have only this single entry in the transitions table.
  **Note** It is possible that we re-define the star to mean 'default'
  transition for a given act in the future and lift this restriction.

* A transition that *ends* in `...` (continuation) must be followed by a
  transiton that *starts* with a `...` (continuation); the inverse also holds.
  IOW, continuation points and tails must always occur in immediately adjacent
  lines of the transitions table.

* For the time being, a transition with a continuation tail must have a
  walkthrough act. That is, a series of commands that are connected by `...`
  (continuations) can not wait for a specific action anywhere; such series must
  always run to completion until a properly named point is reached.

# No More FDWs FTW

see [documentation/no-more-fdws-ftw.md](documentation/no-more-fdws-ftw.md)

