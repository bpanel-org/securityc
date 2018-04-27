#!/bin/bash

function append() {
    echo "$1 $2"
}

function log() {
    if [ $verbose == true ]; then
        echo
        printf "%s" "$1"
        echo
    fi
}
