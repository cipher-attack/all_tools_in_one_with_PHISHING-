#!/usr/bin/env bash

# install if missing (works on Termux/Debian-like)
if ! command -v figlet >/dev/null 2>&1; then
  (command -v pkg >/dev/null && pkg install -y figlet) || sudo apt-get update && sudo apt-get install -y figlet
fi
if ! command -v lolcat >/dev/null 2>&1; then
  (command -v pkg >/dev/null && pkg install -y ruby) || sudo apt-get install -y ruby
  gem install lolcat --no-document
fi

clear
figlet -f slant "CIPHER" | lolcat
echo "" | lolcat
echo "          by cipher" | lolcat
