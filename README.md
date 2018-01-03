

# Bookmarks Organizer

## Installation

### Dependencies

#### PostGreSQL

```sh
sudo apt install postgresql-server-dev-9.6
sudo apt install postgresql-plpython3-9.6
sudo apt install postgresql-contrib-9.6
sudo apt install postgresql-9.6-pgtap
sudo apt install postgresql-9.6-plsh
# sudo apt install postgresql-9.6-python3-multicorn
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


