#!/bin/bash
# Dotted Toolkit
# ----
# Dotted - A dotfile management utility
# By demaisj - 2017

SCRIPT=$(realpath "$0")
SCRIPTPATH=${SCRIPT%/*}
WORKSPACE=$SCRIPTPATH

THIS=$0
ARGV=($@)
ARGC=$#

VERSION="0.1"

GITHUB_URL="https://github.com/"
GITHUB_REPO="demaisj/dotted"
GITHUB_BRANCH="master"

# ----------------
# UTILS
# ----------------

function errcho() {
  (>&2 echo $@)
}

function contains() {
  local -n a=$1
  for word in ${a[@]}; do
    if [ "$word" == "$2" ]; then
      return
    fi
  done
  return 1
}

function get_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if contains SUPPORTED_DISTRO $ID; then
      echo $ID
      return
    fi
    for like in ${ID_LIKE[@]}; do
      if contains SUPPORTED_DISTRO $like; then
        echo $like
        return
      fi
    done
    echo $ID
  else
    if [ -f /etc/arch-release ]; then
      echo "arch"
    else
      echo "unknown"
    fi
  fi
}

function error() {
  errcho "$THIS: $@"
  exit 1
}

function usage() {
  errcho "Usage: $THIS <COMMAND> [<ARGS>]"
  errcho "Try '$THIS help' for more information."
  exit 1
}

function prompt_yn() {
  if [ -z "$2" ] || [ $2 -eq 0]; then
    choice="(Y/n)"
    default=0
  else
    choice="(y/N)"
    default=1
  fi
  while true; do
    read -e -n 1 -p "$1 $choice: " answer
    case $answer in
      [Yy] ) return 0;;
      [Nn] ) return 1;;
      "" ) return $default;;
      * ) errcho "Please type y or n.";;
    esac
  done
}

function prompt_txt() {
  choice=""
  if ! [ -z "$2" ]; then
    choice=" ($2)"
  fi
  while true; do
    read -e -p "$1$choice: " answer
    case $answer in
      "" ) if [ -z "$2" ]; then
          errcho "Please type something."
        else
          echo "$2"
          return 0
        fi;;
      * ) echo "$answer"
        return 0;;
    esac
  done
}

function repo() {
  git -C "$WORKSPACE" $@
}

OS=$(uname --operating-system)
HOSTNAME=$(uname --nodename)
DISTRO=$(get_distro)

# ----------------
# HELP
# ----------------

function cmd_help() {
  echo "help"
  exit 0
}

# ----------------
# VERSION
# ----------------

function cmd_version() {
  echo "$THIS version $VERSION"
  exit 0
}

# ----------------
# UPGRADE
# ----------------

function cmd_upgrade() {
  echo "Checking for updates..."
  TMP="$(mktemp)"
  if ! curl -fsSL "$GITHUB_URL$GITHUB_REPO/raw/$GITHUB_BRANCH/dotted.sh" > "$TMP"; then
    error "Could not retrieve updates!"
  fi
  if ! diff -q $SCRIPT $TMP >/dev/null; then
    if prompt_yn "There is an update available. Apply?"; then
      cp $TMP $SCRIPT
      echo "Dotted is now up to date!"
    else
      rm $TMP
      exit 1
    fi
  else
    echo "Dotted is already up to date!"
  fi
  rm $TMP
  exit 0
}

# ----------------
# SYNC
# ----------------

function cmd_sync() {
  echo "Syncing repo..."
  STATUS=$(repo status --porcelain | tail -n1)
  if [[ -n $STATUS ]]; then
    repo add --all >/dev/null
    repo commit -qm "[sync] $USER@$HOSTNAME - $(date "+%Y-%m-%d %H:%M:%S")" >/dev/null
  fi
  if repo remote show | grep "origin" >/dev/null; then
    BRANCH=$(repo rev-parse --abbrev-ref HEAD)
    repo pull -q --no-edit origin "$BRANCH" >/dev/null
    repo push -q origin "$BRANCH" >/dev/null
  fi
  echo "Done."
  exit 0
}

function cmd_sync_url() {
  if [[ -n $1 ]]; then
    if repo remote show | grep "origin" >/dev/null; then
      repo remote set-url origin "$1"
    else
      repo remote add origin "$1"
    fi
  else
    if repo remote show | grep "origin" >/dev/null; then
      repo remote get-url origin
    else
      error "No sync remote set up!"
    fi
  fi
  exit 0
}


[ $ARGC == 0 ] && usage
[ "$1" == "help" ] && cmd_help ${ARGV[@]:1}
[ "$1" == "version" ] && cmd_version ${ARGV[@]:1}
[ "$1" == "upgrade" ] && cmd_upgrade ${ARGV[@]:1}

[ "$1" == "sync" ] && cmd_sync ${ARGV[@]:1}
[ "$1" == "sync-url" ] && cmd_sync_url ${ARGV[@]:1}
error "'$1' is not a valid command."