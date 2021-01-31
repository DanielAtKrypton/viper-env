# Viper Env Z-Shel plugin

Automatically activates and deactivates python virtualenv upon cd in and out.

## Inspiration

Based on [_MS](https://stackoverflow.com/users/8694152/ms) [answer](https://stackoverflow.com/a/50830617/11685534), I decided to go one step further and implement it as a Z-Shell plugin.

## Usage
<!-- [![asciicast](https://asciinema.org/a/4iMwcKfBS1dc1EgI1FihrDVxT.svg)](https://asciinema.org/a/4iMwcKfBS1dc1EgI1FihrDVxT) -->

![Alt text](./make_animation/assets/final.svg)

## Example
```zsh
> viper-env help

Description:
  Automatically activates and deactivates python virtualenv upon cd in and out.

Dependencies:
  - zsh
  - direnv
  - python

Example usage:
  # Create virtual environment
  python -m venv .venv
  # Activate it
  . .venv/bin/activate
  # Create direnv file
  export VIRTUAL_ENV=venv > .envrc
  # Allow it
  direnv allow .
  # Save current dir
  current_dir=$(basename $PWD)
  # Exit current directory
  cd ..
  # Reenter it
  cd $current_dir
```
