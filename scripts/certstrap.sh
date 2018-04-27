#!/bin/bash

set -eou pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/common.sh

# set initial values
ca_common_name=""
cert_common_name=""
ip=""
domain=""
verbose=false

ca_path_out="$DIR/ca.crt"
ca_key_path_out="$DIR/ca.key"
cert_path_out="$DIR/cert.crt"
key_path_out="$DIR/key.crt"
ca_path_in="$DIR/ca.crt"
ca_key_path_in="$DIR/ca.key"

# TODO: update usage
function usage() {
  echo "generate a ca cert, a csr, then sign"
  echo "-c|--ca-common-name - common name on generated ca cert"
  echo "-ce|--cert-common-name - common name on generated cert"
  echo "-ip|--ip - ip on X509v3 Subject Alternative Name, can be multiple values comma separated"
  echo "-d|--domain - dns on X509v3 Subject Alternative Name, can be multiple values comman separated"
  echo "-ao|--ca-path-out - path to generated ca"
  echo "-co|--cert-path-out - path to generated cert"
  echo "-ko|--key-path-out - path to generated key"
  echo "-v|--verbose"
}

# move a file from first arg to second arg
function move() {
  chmod u+w "$1"
  log $'Running command:\n'"mv $1 $2"
  mv -f "$1" "$2"
  chmod u-w "$2"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  --ca-common-name) ca_common_name="$2"; shift;;
  --cert-common-name) cert_common_name="$2"; shift;;
  --ip) ip="$2"; shift;;
  --domain) domain="$2"; shift;;
  --ca-in) ca_path_in="$2"; shift;;
  --ca-key-in) ca_key_path_in="$2"; shift;;
  --ca-key-out) ca_key_path_out="$2"; shift;;
  --ca-out) ca_path_out="$2"; shift;;
  --cert-out) cert_path_out="$2"; shift;;
  --key-out) key_path_out="$2"; shift;;
  -v|--verbose) verbose=true;;
  *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done

log "Running from directory: $PWD"

OUT_DIR=
# handle case when in root to prevent double /
if [ "$PWD" == "/" ]; then
    OUT_DIR="/out"
else
    OUT_DIR="${PWD}/out"
fi

log "CA Common Name: $ca_common_name"

# create new ca if one doesn't exist already
if [[ ! -f "$ca_path_in" ]]; then
    # create the files:
    # "$PWD/out/$ca_common_name.key"
    # "$PWD/out/$ca_common_name.crt"
    # "$PWD/out/$ca_common_name.crl"
    log "Invoking certstrap init with args: --common-name $ca_common_name --passphrase \"\""
    certstrap init --common-name "$ca_common_name" --passphrase ""
else
    log "CA present at $ca_path_in"
    # make sure that the ca key is present
    # this is needed to do signing
    if [[ -f "$ca_key_path_in" ]]; then
        log "CA key found at $ca_key_path_in"
        # move CA to directory certstrap uses
        mkdir -p "$OUT_DIR"
        log "moving $ca_path_in to $OUT_DIR/$ca_common_name.crt"
        move "$ca_path_in" "$OUT_DIR/$ca_common_name.crt"
        log "moving $ca_key_path_in" "$OUT_DIR/$ca_common_name.key"
        move "$ca_key_path_in" "$OUT_DIR/$ca_common_name.key"
    else
        echo "please provide the CA key"
    fi
fi

# append to request_cert_arg only if the lengths of
# the environmental variables are not zero
request_cert_arg=""
[[ ! -z "$cert_common_name" ]] && request_cert_arg="${request_cert_arg} --common-name ${cert_common_name}"
[[ ! -z "$ip" ]] && request_cert_arg="${request_cert_arg} --ip ${ip}"
[[ ! -z "$domain" ]] && request_cert_arg="${request_cert_arg} --domain ${domain}"

log $'Invoking:\n'"certstrap request-cert ${request_cert_arg} --passphrase \"\""
# create the files:
# "$PWD/out/$cert_common_name.key"
# "$PWD/out/$cert_common_name.csr"
certstrap request-cert $request_cert_arg --passphrase ""

# creates the file:
# "$PWD/out/$cert_common_name.crt"
log $'Invoking:\n'"certstrap sign ${cert_common_name} --CA ${ca_common_name}"
certstrap sign "${cert_common_name}" --CA "${ca_common_name}"

# move these files to the proper location
ca_file="$OUT_DIR/$ca_common_name.crt"
ca_key_file="$OUT_DIR/$ca_common_name.key"
cert_file="$OUT_DIR/$cert_common_name.crt"
key_file="$OUT_DIR/$cert_common_name.key"

# move each of the files to their
# user specified locations
move "$ca_file" "$ca_path_out"
move "$ca_key_file" "$ca_key_path_out"
move "$cert_file" "$cert_path_out"
move "$key_file" "$key_path_out"

log "cleaning up $OUT_DIR"
rm -rf "$OUT_DIR"

