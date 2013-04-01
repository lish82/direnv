#!/usr/bin/env bash
#
# These are the commands available in an .envrc context

set -e

if [ -z "$1" ]; then
  echo "Missing .envrc path" >&2
  exit 1
fi

DIRENV_LIBEXEC="$(dirname $0)"
ENVRC_PATH="$1"

# Usage: has something
# determines if "something" is availabe as a command
has() {
  type "$1" &>/dev/null
}

# Usage: expand_path ./rel/path [RELATIVE_TO]
# RELATIVE_TO is $PWD by default
expand_path() {
  "$DIRENV_LIBEXEC/direnv" private expand_path "$@"
}

# Usage: dotenv
# Loads a .env in the current environment
dotenv() {
  eval "$("$DIRENV_LIBEXEC/direnv" private dotenv "$@")"
}

# Usage: user_rel_path /Users/you/some_path => ~/some_path
user_rel_path() {
  local path="${1#-}"

  if [ -z "$path" ]; then return; fi

  if [ -n "$HOME" ]; then
    local rel_path="${path#$HOME}"
    if [ "$rel_path" != "$path" ]; then
      path="~${rel_path}"
    fi
  fi

  echo $path
}

# Usage: find_up some_file
find_up() {
  (
    cd "$(pwd -P 2>/dev/null)"
    while true; do
      if [ -f "$1" ]; then
        echo $PWD/$1
        return 0
      fi
      if [ "$PWD" = "/" ] || [ "$PWD" = "//" ]; then
        return 1
      fi
      cd ..
    done
  )
}

direnv_find_rc() {
  local path="$(find_up .envrc)"
  if [ -n "$path" ]; then
    cd "$(dirname "$path")"
    return 0
  else
    return 1
  fi
}

# Safer PATH handling
#
# Usage: PATH_add PATH
# Example: PATH_add bin
PATH_add() {
  export PATH="$(expand_path "$1"):$PATH"
}

# Safer path handling
#
# Usage: path_add VARNAME PATH
# Example: path_add LD_LIBRARY_PATH ./lib
path_add() {
  local old_paths=${!1}
  local path="$(expand_path "$2")"

  if [ -z "$old_paths" ]; then
    old_paths="$path"
  else
    old_paths="$path:$old_paths"
  fi

  export $1="$old_paths"
}

# Usage: layout ruby
layout_ruby() {
  # TODO: ruby_version should be the ABI version
  local ruby_version="$(ruby -e"puts (defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby') + '-' + RUBY_VERSION")"

  export GEM_HOME="$PWD/.direnv/${ruby_version}"
  export BUNDLE_BIN="$PWD/.direnv/bin"

  PATH_add ".direnv/${ruby_version}/bin"
  PATH_add ".direnv/bin"
}

layout_python() {
  if ! [ -d .direnv/virtualenv ]; then
    virtualenv --no-site-packages --distribute .direnv/virtualenv
    virtualenv --relocatable .direnv/virtualenv
  fi
  source .direnv/virtualenv/bin/activate
}

layout_node() {
  PATH_add node_modules/.bin
}

layout() {
  eval "layout_$1"
}

# This folder contains a <program-name>/<version> structure
cellar_path=/usr/local/Cellar
set_cellar_path() {
  cellar_path="$1"
}

# Usage: use PROGRAM_NAME VERSION
# Example: use ruby 1.9.3
use() {
  if has use_$1 ; then
    echo "Using $1 v$2"
    eval "use_$1 $2"
    return $?
  fi

  local path="$cellar_path/$1/$2/bin"
  if [ -d "$path" ]; then
    echo "Using $1 v$2"
    PATH_add "$path"
    return
  fi

  echo "* Unable to load $path"
  return 1
}

# Inherit another .envrc
# Usage: source_env <FILE_OR_DIR_PATH>
source_env() {
  local rcfile="$1"
  if ! [ -f "$1" ]; then
    rcfile="$rcfile/.envrc"
  fi
  echo "direnv: loading $(user_rel_path "$rcfile")"
  pushd "$(dirname "$rcfile")" > /dev/null
  set +u
  . "./$(basename "$rcfile")"
  popd > /dev/null
}

# Inherits the first .envrc (or given FILE_NAME) it finds in the path
# Usage: source_up [FILE_NAME]
source_up() {
  local file="$1"
  if [ -z "$file" ]; then
    file=".envrc"
  fi
  local path="$(cd .. && find_up "$file")"
  if [ -n "$path" ]; then
    source_env "$path"
  fi
}

if [ -n "${rvm_path-}" ]; then
  # source rvm on first call
  rvm() {
    unset rvm
    set +e
    . "$rvm_path/scripts/rvm"
    rvm $@
    set -e
  }
fi


## The actual runtime ##

if [ -f ~/.direnvrc ]; then
  source_env ~/.direnvrc >&2
fi

source_env "$ENVRC_PATH" >&2

"$DIRENV_LIBEXEC/direnv" private dump