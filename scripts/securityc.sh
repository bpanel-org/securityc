#!/bin/bash

set -eou pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# get common functions
. $DIR/common.sh

verbose=false
while [[ "$#" -gt 0 ]]; do case $1 in
  -v|--verbose) verbose=true;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# get the input env vars
input=$(env | grep SECURITYC)

log $'input:\n'"$input"

# split key=value by = to get env var keys then split by _
# to grap the app name
awk_cmd='{ split($1,var_names,"="); split(var_names[1],app_names,"_"); print app_names[2] }'
# TODO: this is fragile to user input, if they pass an extra _ before the app name

apps=$(echo "$input" | \
    awk "$awk_cmd" \
    | sort -u)

log $'apps:\n'"$apps"

function parse_env_config() {
    local var
    local result=""
    # string interpolate the name of the env var
    var="SECURITYC_${1}_${2}"
    # get the value of the env var itself
    # see https://www.tldp.org/LDP/abs/html/abs-guide.html#IVR
    # look before you leap
    if env | grep "$var" &>/dev/null; then
        result=$(eval "echo \$$(echo $var)")
    fi
    echo "$result"
}

# run tls.sh for each set of args
for app in $apps; do
    # get the environmental variable values
    arg_ca_common_name=$(parse_env_config "${app}" "CA_COMMON_NAME")
    arg_cert_common_name=$(parse_env_config "${app}" "CERT_COMMON_NAME")
    arg_cert_ip=$(parse_env_config "${app}" "CERT_IP")
    arg_cert_domain=$(parse_env_config "${app}" "CERT_DOMAIN")

    # path to CA and CA key out
    arg_ca_out=$(parse_env_config "${app}" "CA_OUT")
    arg_ca_key_out=$(parse_env_config "${app}" "CA_KEY_OUT")
    # path to CA and key in
    arg_ca_in=$(parse_env_config "${app}" "CA_IN")
    arg_ca_key_in=$(parse_env_config "${app}" "CA_KEY_IN")
    # path to leaf cert and key out
    arg_key_out=$(parse_env_config "${app}" "KEY_OUT")
    arg_cert_out=$(parse_env_config "${app}" "CERT_OUT")

    # different cases:
    # 1. provided ca + generate leaf cert/key
    #  - ca specific
    #    CA_IN, CA_KEY_IN
    #  - cert specific
    #    CERT_OUT, KEY_OUT, CERT_COMMON_NAME, CERT_IP, CERT_DOMAIN
    # 2. generate ca + generate leaf cert/key
    #  - ca specific:
    #    CA_COMMON_NAME, CA_OUT, CA_KEY_OUT
    #  - cert specific:
    #    CERT_OUT, KEY_OUT, CERT_COMMON_NAME, CERT_IP, CERT_DOMAIN

    # require at least one of CERT_IP and CERT_DOMAIN
    if [[ -z "$arg_cert_ip" ]] && [[ -z "$arg_cert_domain" ]]; then
        echo "Please provide at least one of CERT_IP and CERT_DOMAIN"
        echo "SECURITYC_${app}_CERT_IP=${arg_cert_ip}"
        echo "SECURITYC_${app}_DOMAIN=${arg_cert_domain}"

        echo "skipping certificate generation"
    # require CERT_OUT, KEY_OUT, CERT_COMMON_NAME, CA_COMMON_NAME
    elif [[ -z "$arg_cert_common_name" ]] || [[ -z "$arg_cert_out" ]] \
        || [[ -z "$arg_key_out" ]] || [[ -z "$arg_ca_common_name" ]]; then
        echo "Please provide CERT_OUT, KEY_OUT, CERT_COMMON_NAME, CA_COMMON_NAME"
        echo "SECURITYC_${app}_CERT_OUT=${arg_cert_out}"
        echo "SECURITYC_${app}_KEY_OUT=${arg_key_out}"
        echo "SECURITYC_${app}_CERT_COMMON_NAME=${arg_cert_common_name}"
        echo "SECURITYC_${app}_CA_COMMON_NAME=${arg_ca_common_name}"

        echo "skipping certificate generation"
    # both or neither CA_IN and CA_KEY_IN must be provided
    elif ( ([[ ! -z "$arg_ca_in" ]] && [[ -z "$arg_ca_key_in" ]]) \
        || ([[ -z "$arg_ca_in" ]] && [[ ! -z "$arg_ca_key_in" ]]) ); then
        echo "Please provide both or neither of CA_IN and CA_KEY_IN"
        echo "cert common name: $arg_cert_common_name"
        echo "SECURITYC_${app}_CA_IN=${arg_ca_in}"
        echo "SECURITYC_${app}_CA_KEY_IN=${arg_ca_key_in}"

        echo "skipping certificate generation"
    else
        # start the script args as an empty string
        script_args=""

        # CA_IN is provided and is the path to a file
        if [[ ! -z "$arg_ca_in" ]] && [[ -f "$arg_ca_in" ]]; then
            log "using provided ca at $arg_ca_in"
            script_args=$(append "$script_args" "--ca-in ${arg_ca_in}")
        fi
        # CA_KEY_IN is provided and is the path to a file
        if [[ ! -z "$arg_ca_key_in" ]] && [[ -f "$arg_ca_key_in" ]]; then
            log "using provided ca key at $arg_ca_key_in"
            script_args=$(append "$script_args" "--ca-key-in ${arg_ca_key_in}")
        fi

        # append required args: CERT_OUT, KEY_OUT, CERT_COMMON_NAME, CA_COMMON_NAME
        script_args=$(append "$script_args" "--cert-out ${arg_cert_out} --key-out ${arg_key_out}")
        script_args=$(append "$script_args" "--cert-common-name ${arg_cert_common_name} --ca-common-name ${arg_ca_common_name}")
        # only append if not empty
        [[ ! -z "$arg_cert_ip" ]] && script_args=$(append "$script_args" "--ip ${arg_cert_ip}")
        [[ ! -z "$arg_cert_domain" ]] && script_args=$(append "$script_args" "--domain ${arg_cert_domain}")

        # args for creating CA
        [[ ! -z "$arg_ca_out" ]] && script_args=$(append "$script_args" "--ca-out ${arg_ca_out}")
        [[ ! -z "$arg_ca_key_out" ]] && script_args=$(append "$script_args" "--ca-key-out ${arg_ca_key_out}")

        log $'script args\n'"$script_args"

        if [ $verbose = true ]; then
            # append verbose flag if verbose is true
            log "successfully parsed all arguments"
            script_args=$(append "$script_args" "-v")
            log $'calling:\n'"$DIR/certstrap.sh ${script_args}"
        fi

        # invoke the script, don't quote as we
        # want the arguments to split
        $DIR/certstrap.sh ${script_args}

        log "completed generating certs for $app"
    fi
done

echo "done generating certs"
echo "exiting securityc.sh"

