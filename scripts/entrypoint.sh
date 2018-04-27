#!/bin/bash

echo "securityc start"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# for append function
source $DIR/common.sh

verbose=
while [[ "$#" -gt 0 ]]; do case $1 in
  -v|--verbose) verbose='-v';;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

args=$(append "$args" "$verbose")

echo "starting cert generation"

$DIR/securityc.sh $args

$DIR/nginx.sh

