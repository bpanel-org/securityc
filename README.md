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
for rendering templates with environment variables.

## Usage

Building the container

```bash
$ docker build -t securityc:latest .
```

Automatically generate a CA cert/key pair using certstrap or provide a CA cert/key pair to
create leaf certificate cert/key pairs.
securityc is configured with environment variables.

TLS Certificate generation uses these environment variables:

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

Optionally bring up `nginx` to use as a reverse proxy.
If you already have your own cert/key pair that you would like to use with `nginx`,
mount them into the container at runtime at the paths:

- `/etc/ssl/nginx/tls.crt` for the certificate
- `/etc/ssl/nginx/tls.key` for the key

or set custom paths for `nginx` to look for the cert and key using the environment variables:

- `NGINX_SSL_CERTIFICATE` - Path to file with certificate in PEM format [docs](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate)
- `NGINX_SSL_CERTIFICATE_KEY` - Path to secret key in PEM format [docs](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate_key)

To enable `nginx`, use the environment variable:

- `USE_NGINX` - Start the nginx reverse proxy if set

To set the URI of the upstream service, use the environment variable:

- `NGINX_UPSTREAM_URI` - URI for upstream application

This will be rendered into the `nginx.conf` at runtime.


## Example configuration


```bash
# common names
export CA_COMMON_NAME=bpanel
export CERT_COMMON_NAME=localhost

# x509v3 SAN fields - at least one must be provided
export CERT_IP=127.0.0.1
export CERT_DOMAIN=localhost

# path to generated CA cert/key
export CA_OUT=/etc/ssl/certs/ca.crt
export CA_KEY_OUT=/etc/ssl/certs/ca.key

# path to provided CA cert/key
export CA_IN=/etc/ssl/certs/ca.crt
export CA_KEY_IN=/etc/ssl/certs/ca.key

# path to generated leaf cert/key
export CERT_OUT=/etc/nginx/tls.crt
export KEY_OUT=/etc/nginx/tls.key

# use the generated cert/key
export NGINX_SSL_CERTIFICATE=/etc/nginx/tls.crt
export NGINX_SSL_CERTIFICATE_KEY=/etc/nginx/tls.key
export NGINX_UPSTREAM_URI=app:5000
```

These environment variables must be passed into the container at runtime.
If using `docker-compose`, they can be directly passed into the container like so:

```
version: '3'
services:
  reverse-proxy:
    image: bpanel/securityc
    environment:
      - CA_COMMON_NAME=example
      ...
```

Or they can be placed in an env file and passed into the container.
This example assumes that you have all of the environment variables
in a file called `securityc.env` in `KEY=VALUE` format.

```
version: '3'
services:
  reverse-proxy:
    image: bpanel/securityc
    env_file:
      - ./securityc.env
```

You can also pass the environment variables in at runtime using the `-e` flag
with `docker run` like:

```
$ docker run --rm -e CA_COMMON_NAME=bpanel \
  -e CERT_COMMON_NAME=localhost \
  -e CERT_DOMAIN=localhost \
  -e CA_OUT=/etc/ssl/certs/ca.crt \
  -e CA_KEY_OUT=/etc/ssl/certs/ca.key \
  -e CA_IN=/etc/ssl/certs/ca.crt \
  -e CA_KEY_IN=/etc/ssl/certs/ca.key \
  -e CERT_OUT=/etc/nginx/tls.crt \
  -e KEY_OUT=/etc/nginx/tls.key \
  -e NGINX_SSL_CERTIFICATE=/etc/nginx/tls.crt \
  -e NGINX_SSL_CERTIFICATE_KEY=/etc/nginx/tls.key \
  -e NGINX_UPSTREAM_URI=app:5000
```

## Use Cases

Some hardware wallet libraries like [bledger](https://github.com/bcoin-org/bledger) require HTTPS.
Use `securityc` to manage TLS termination so that applications behind it do not need to worry about it.
Some ways to use the certificate management are:

1. User provides CA, auto-generate leaf Cert/Key
  - `CA_IN` and `CA_KEY_IN` are paths to files and are required for for signing
  - At least one of `CERT_IP` and `CERT_DOMAIN` are required for X509v3 SAN fields
  - `CERT_COMMON_NAME` is required to ensure the proper cert is signed
  - `CERT_OUT` and `KEY_OUT` are paths to the generated leaf cert and key and are required
2. Auto-generate CA, auto-generate leaf Cert/Key
  - `CA_COMMON_NAME` is required and will be the CN for the generated CA cert
  - `CA_OUT` and `CA_KEY_OUT` are paths to the generated CA
  - `CERT_COMMON_NAME` is required to ensure the proper cert is signed
  - At least one of `CERT_IP` and `CERT_DOMAIN` are required for X509v3 SAN fields
  - `CERT_OUT` and `KEY_OUT` are paths to the generated leaf cert and key and are required

`nginx` can then be started using the generated certificates

Lets inspect the produced certificates.
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

The value of `CA_COMMON_NAME`
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

The value of `CERT_COMMON_NAME` sets the `Subject CN`,
`CERT_IP` and `CERT_DOMAIN` set the values
of the `X509v3 Subject Alternative Name` `IP Address` and `DNS` fields
respectively.

## TODO Features

- Use events from the docker sock to generate certs on the fly

