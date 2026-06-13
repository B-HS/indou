#!/usr/bin/env bash
set -euo pipefail

# Creates a persistent self-signed code signing identity so repeated local
# builds keep their macOS TCC permissions (Accessibility / Screen Recording).
#
# Without this, ad-hoc (`-`) signed binaries get a new CDHash every build and
# TCC treats each build as a new app → user re-grants permission every time.
#
# Run once: ./scripts/setup-dev-identity.sh
# Then build-app.sh will detect and use it.

CERT_NAME="${CERT_NAME:-Indou Dev}"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
PASS="indoudev"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "\"$CERT_NAME\""; then
    echo "✓ Code signing identity '$CERT_NAME' already present."
    exit 0
fi

echo "==> Creating self-signed code signing identity '$CERT_NAME'"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CERT_NAME

[v3_req]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" \
    -x509 -days 3650 \
    -out "$TMP/cert.pem" \
    -config "$TMP/openssl.cnf" \
    2>/dev/null

openssl pkcs12 -export \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -name "$CERT_NAME" \
    -out "$TMP/cert.p12" \
    -passout "pass:$PASS" \
    -macalg SHA1 \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -legacy \
    2>/dev/null

security import "$TMP/cert.p12" \
    -k "$KEYCHAIN" \
    -P "$PASS" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    >/dev/null

security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "" "$KEYCHAIN" \
    >/dev/null 2>&1 || true

echo "✓ Identity installed."
echo ""
security find-identity -v -p codesigning "$KEYCHAIN" | grep "$CERT_NAME" || true
echo ""
echo "Rebuilds will now preserve your Accessibility / Screen Recording grants."
echo "To remove later:  security delete-certificate -c \"$CERT_NAME\" \"$KEYCHAIN\""
