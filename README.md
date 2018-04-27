# securityc

automatic tls generation based on [certstrap](https://github.com/square/certstrap)
with nginx reverse proxy to terminate tls

## Dependencies

Mac:

```
$ brew install gettext
$ brew link --force gettext
```

The `gettext` package includes `envsubst`, which is a handy program
for rendering templates with environmental variables.

# Usage

Building the container

```bash
$ basename $PWD
> bpanel
$ docker-compose build securityc
```

Generate a CA cert/key pair or provide a CA cert/key pair to create leaf certificate cert/key pairs.
This is useful if you need TLS termination while you are developing, for example some hardware
wallet libraries like [bledger](https://github.com/bcoin-org/bledger) require HTTPS.
securityc is configured with environmental variables. An arbitrary number of certs can be generated,
to properly bundle the inputs per cert, the environmental variables must follow the schema:

```bash
SECURITYC_{APP_NAME}_{ARG_NAME}
```

The prefix `SECURITYC` ensures that there are no collisions with other environmental variables.
The `{APP_NAME}` refers to an application that a cert/private key should be generated for.
The `{ARG_NAME}` refers to an argument that the script needs to generate the cert/private key pair.
The script will be invoked once for each `{APP_NAME}` that has all of the appropriate arguments.
NOTE: valid `{APP_NAME}`s contain `[A-Z]`, please do not include `_` or other characters

The `{ARG_NAME}`s that can be provided are:

- `CA_COMMON_NAME` (REQUIRED) - Subject Common Name for the generated CA
- `CERT_COMMON_NAME` (REQUIRED) - Subject Common Name for the leaf Certificate
- `CERT_IP` - X509v3 SAN IP Address
- `CERT_DOMAIN` - X509v3 SAN DNS
- `CA_OUT` - Output file for generated Certificate Authority
- `CA_KEY_OUT` - Output file for generated Certificate Authority
- `CA_IN` - Path to CA certificate to use for signing
- `CA_KEY_IN` - Path to CA key to use for signing
- `KEY_OUT` (REQUIRED) - Output file for leaf TLS key
- `CERT_OUT` (REQUIRED) - Output file for leaf TLS cert

An example where the `{APP_NAME}` is set to `SERVER` looks like this:

```bash
# common names
export SECURITYC_SERVER_CA_COMMON_NAME=bpanel
export SECURITYC_SERVER_CERT_COMMON_NAME=localhost

# x509v3 SAN fields - at least one must be provided
export SECURITYC_SERVER_CERT_IP=127.0.0.1
export SECURITYC_SERVER_CERT_DOMAIN=localhost

# path to generated CA cert/key
export SECURITYC_SERVER_CA_OUT=/etc/ssl/certs/ca.crt
export SECURITYC_SERVER_CA_KEY_OUT=/etc/ssl/certs/ca.key

# path to provided CA cert/key
export SECURITYC_SERVER_CA_IN=/etc/ssl/certs/ca.crt
export SECURITYC_SERVER_CA_KEY_IN=/etc/ssl/certs/ca.key

# path to generated leaf cert/key
export SECURITYC_SERVER_KEY_OUT=/etc/nginx/tls.key
export SECURITYC_SERVER_CERT_OUT=/etc/nginx/tls.crt
```

## Use Cases

1. Provide CA, Generate leaf Cert/Key
  - `CA_IN` and `CA_KEY_IN` are paths to files and are required for for signing
  - One of `CERT_IP` and `CERT_DOMAIN` are required for X509v3 SAN fields
  - `CERT_COMMON_NAME` is required to ensure the proper cert is used in signing
  - `CERT_OUT` and `KEY_OUT` are paths to the generated leaf cert and key and are required
2. Generate CA, Generate leaf Cert/Key
  - `CA_COMMON_NAME` is required and will be the CN for the generated CA cert
  - `CA_OUT` and `CA_KEY_OUT` are paths to the generated CA
  - `CERT_COMMON_NAME` 
  - One of `CERT_IP` and `CERT_DOMAIN` are required for X509v3 SAN fields
  - `CERT_OUT` and `KEY_OUT` are paths to the generated leaf cert and key and are required


Lets inspect the produced certificates with:
Note, not all of the output is displayed

First up, the Certificate Authority

```bash
$ openssl x509 -noout -text -in /etc/ssl/certs/ca.crt
```

```
Signature Algorithm: sha256WithRSAEncryption
    Issuer: CN=bpanel
    Validity
        Not Before: Apr 19 18:31:39 2018 GMT
        Not After : Oct 19 18:31:39 2019 GMT
    Subject: CN=bpanel

------- removed for brevity -------------------

    X509v3 extensions:
        X509v3 Key Usage: critical
            Certificate Sign, CRL Sign
        X509v3 Basic Constraints: critical
            CA:TRUE, pathlen:0
```

The value of `SECURITYC_SERVER_CA_COMMON_NAME`
is set as the `Subject CN` and you can see that the certificate is a CA that
can do certificate signing.


Now the requested Certificate

```bash
$ openssl x509 -noout -text -in /etc/nginx/tls.crt
```

```
Signature Algorithm: sha256WithRSAEncryption
    Issuer: CN=bpanel
    Validity
        Not Before: Apr 19 18:31:44 2018 GMT
        Not After : Oct 19 18:31:38 2019 GMT
    Subject: CN=localhost

------- removed for brevity -------------------

    X509v3 extensions:
        X509v3 Key Usage: critical
            Digital Signature, Key Encipherment, Data Encipherment, Key Agreement
        X509v3 Extended Key Usage:
            TLS Web Server Authentication, TLS Web Client Authentication

------- removed for brevity -------------------

    X509v3 Subject Alternative Name:
        DNS:localhost, IP Address:127.0.0.1
```

The value of `SECURITYC_SERVER_CERT_COMMON_NAME` sets the `Subject CN`, 
`SECURITYC_SERVER_CERT_IP` and `SECURITYC_SERVER_CERT_DOMAIN` set the values
of the `X509v3 Subject Alternative Name` `IP Address` and `DNS` fields
respectively.

## TODO Features

- `envsubst` auto generation of `nginx.conf`

