#!/bin/sh

cd `dirname $0`

if [ -z $(which clang-format) ] ; then
  echo "clang-format not found."
  echo "Install Homebrew, then:"
  echo "brew install clang-format"
  echo ""
  echo "Aborting."
  exit
fi

find . \( -name "*.metal" -o -name "*.metal.txt" \) | while read _fmt_f; do
clang-format -i -style=file:./clang-format "$_fmt_f"
done
