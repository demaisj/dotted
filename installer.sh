#!/bin/bash
# Dotted Installer
# ----
# Dotted - A dotfile management utility
# By demaisj - 2017

GITHUB_URL="https://github.com/"
GITHUB_REPO="demaisj/dotted"
GITHUB_BRANCH="master"

function contains() {
  local -n a=$1
  for word in ${a[@]}; do
    if [ "$word" == "$2" ]; then
      return
    fi
  done
  return 1
}

function errcho() {
  (>&2 echo $@)
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

function pkg_is_installed() {
  if [ "$DISTRO" == "arch" ]; then
    pacman -Qi $1 >>/dev/null 2>&1
    return $?
  fi
  return 1
}

function pkg_update() {
  if [ "$DISTRO" == "arch" ]; then
    sudo pacman -Sy
    return $?
  fi
  return 1
}

function pkg_install() {
  if [ "$DISTRO" == "arch" ]; then
    sudo pacman -S $@
    return $?
  fi
  return 1
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

SUPPORTED_OS=("GNU/Linux")
SUPPORTED_DISTRO=("arch")
DEPENDENCIES=("git" "stow" "curl")

OS=$(uname --operating-system)
HOSTNAME=$(uname --nodename)
DISTRO=$(get_distro)

echo "1) Verifying environment..."

if ! contains SUPPORTED_OS $OS; then
  errcho "Your Operating System is not supported right now!"
  exit 1
fi

if ! contains SUPPORTED_DISTRO $DISTRO; then
  errcho "Your GNU/Linux Distribution is not supported right now!"
  exit 1
fi

echo "2) Checking dependencies..."
MISSING_PKGS=()
MISSING_COUNT=0
for dep in ${DEPENDENCIES[@]}; do
  if ! pkg_is_installed $dep; then
    echo "- $dep is not installed."
    MISSING_PKGS+=("$dep")
    MISSING_COUNT+=1
  fi
done

if [[ MISSING_COUNT -gt 0 ]]; then
  echo "$MISSING_COUNT packages are missing."
  echo "Starting package manager..."
  pkg_update
  if ! pkg_install ${MISSING_PKGS[@]}; then
    errcho "Failed to install critical dependencies!"
    exit 1
  fi
fi

echo "3) Creating dotted workspace..."
eval DEST="$(prompt_txt "Dotted workspace location" "~/.dotted")"
if prompt_yn "Do you want to clone an existing workspace?"; then
  eval URL="$(prompt_txt "Git repository URL")"
  if ! git clone "$URL" "$DEST"; then
    errcho "Failed to clone repository!"
    exit 1
  fi
else
  echo "Creating a new git repository..."
  if ! mkdir -p "$DEST"; then
    errcho "Could not create directory"
  fi
  git -C "$DEST" init
  echo "Downloading latest toolkit version..."
  if ! curl -fsSL "$GITHUB_URL$GITHUB_REPO/raw/$GITHUB_BRANCH/dotted.sh" > "$DEST/dotted.sh"; then
    errcho "Could not download toolkit!"
    exit 1
  fi
  chmod 755 "$DEST/dotted.sh"
  git -C "$DEST" add "$DEST" >> /dev/null
  git -C "$DEST" commit -m "Initial commit" >> /dev/null
fi

echo "4) Initializing workspace..."
echo "Running $DEST/dotted.sh init"
"$DEST/dotted.sh" init