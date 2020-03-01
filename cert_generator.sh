#!/bin/bash
# certt-generator:
#   1st arg: Create CA
#   2st arg: CA arguments separated by commas "/C=US/ST=Utah/L=Provo/O=ACME Signing Authority Inc/CN=example.com"
#   3st arg: cert name
#   4st arg: Domain
#   5st arg: Sign with his CA
#   6st arg: CA private key
set -e

# make directories to work from
mkdir -p server/ client/ all/

#CA argument. Create CA authorithy
if [[ -n $1 ]]; then
    mkdir -p ca/

    # Create your very own Root Certificate Authority
    openssl genrsa \
        -out all/my-private-root-ca.privkey.pem \
        2048

    if [[ -n $2 ]]; then
        ARR_SUBJ=(${2//,/ })
    else
        ARR_SUBJ=("US" "California" "Sacramento" "ACME Signing Authority" "example.com")
    fi

    # Self-sign your Root Certificate Authority
    openssl req \
        -x509 \
        -new \
        -nodes \
        -key all/${1}.privkey.pem \
        -days 2048 \
        -out all/${1}-ca.cert.pem \
        -subj "/C=${ARR_SUBJ[0]}/ST=${ARR_SUBJ[1]}/L=${ARR_SUBJ[2]}/O=${ARR_SUBJ[3]}/CN=${ARR_SUBJ[4]}"
    
    exit 0
fi

NAME=$3
FQDN=$4
CA=$5
CA_PRIV_KEY=$6

BASE_DNS="DNS.1   = "
BASE_COMMON_NAME="commonName                 = "

DNS_LINE=$(cat cert.conf | grep -nr DNS\.1 | awk -F ":" '{print $2}')
COMMON_NAME_LINE=$(cat cert.conf | grep -nr commonName | awk -F ":" '{print $2}')

ex -sc "${DNS_LINE}d|x" cert.conf
ex -sc "${DNS_LINE}i|${BASE_DNS}$FQDN" -cx cert.conf

ex -sc "${COMMON_NAME_LINE}d|x" cert.conf
ex -sc "${COMMON_NAME_LINE}i|${BASE_COMMON_NAME}$FQDN" -cx cert.conf

openssl genrsa \
    -out all/${NAME}-privkey.pem \
    2048

if [[ -n $CA ]]; then
    # Create a request from your Device, which your Root CA will sign
    openssl req -new \
        -key all/${NAME}-privkey.pem \
        -out all/${NAME}-csr.pem \
        -config cert.conf

    # Sign the request from Device with your Root CA
    openssl x509 \
        -req -in all/${NAME}-csr.pem \
        -CA $CA \
        -CAkey $CA_PRIV_KEY \
        -CAcreateserial \
        -out all/${NAME}.pem \
        -extensions v3_req \
        -extfile cert.conf \
        -days 500

    exit 0
else
    openssl x509 \
        -req -x509 \
        -nodes \
        -key all/${NAME}-privkey.pem \
        -out all/${NAME}.pem \
        -extensions v3_req \
        -extfile cert.conf \
        -days 500

    exit 0
fi



# Put things in their proper place
#rsync -a all/{privkey,cert}.pem server/
#cat all/cert.pem > server/fullchain.pem         # we have no intermediates in this case
#rsync -a all/my-private-root-ca.cert.pem server/
#rsync -a all/my-private-root-ca.cert.pem client/

# create DER format crt for iOS Mobile Safari, etc
#openssl x509 -outform der -in all/my-private-root-ca.cert.pem -out client/my-private-root-ca.crt