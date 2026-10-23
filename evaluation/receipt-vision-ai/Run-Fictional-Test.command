#!/bin/zsh
cd -- "${0:A:h}" || exit 1
/usr/bin/python3 lab.py smoke
printf '\nPress Return to close. '
read -r reply
