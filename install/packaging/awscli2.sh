#!/usr/bin/env bash

set -euo pipefail

# AWS CLI v2, from AWS rather than from Fedora. Fedora does package awscli2, and for most
# tools that would settle it -- but this is the one the day job is driven through, and
# AWS supports only their own build. The same reasoning already put helm, terraform and
# restic in their own scripts here.
#
# The zip is verified before anything is run as root. `sudo ./aws/install` executes code
# out of a 70MB download, so "it came over TLS" is not enough on its own; the signing key
# is pinned below rather than fetched, so a keyserver cannot be talked into handing over
# a different one.

ARCH=$(uname -m)
case "$ARCH" in
x86_64) ZIP="awscli-exe-linux-x86_64.zip" ;;
aarch64) ZIP="awscli-exe-linux-aarch64.zip" ;;
*)
  echo "❌ No AWS CLI v2 build for $ARCH"
  exit 1
  ;;
esac

BASE="https://awscli.amazonaws.com"
# Published at docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html.
# Key A6310ACC4672475C, AWS CLI Team <aws-cli@amazon.com>, expires 2027-07-01 -- this
# script starts failing verification then, which is the point.
FINGERPRINT="FB5DB77FD5C118B80511ADA8A6310ACC4672475C"

echo "📌 Installing AWS CLI v2 ..."

sudo dnf install -y curl unzip gnupg2

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "🔽 Downloading $ZIP ..."
curl -fsSL "$BASE/$ZIP" -o "$TMPDIR/awscliv2.zip"
curl -fsSL "$BASE/$ZIP.sig" -o "$TMPDIR/awscliv2.sig"

cat >"$TMPDIR/aws-cli.pgp" <<'KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
akV0ygUJDqP4lQAKCRCmMQrMRnJHXFHjD/9eyZLYcKuQOlLvtqSDtUBiEZf6ZZjM
i3ygYH8rJNtuToUH+HvSpe819urJCquXhDrlK6N+aqW0hCLtNABJG/vsafIgvIYJ
hSGgpgtNnQyMV1jViRWqPjbouw8OkYKBThUfT1i2Y+wn58ifs6ODBCmTexWtXspA
Si+Gt49xDOW0APmbOPnI+a4HJW6tVEo6MWS0WjzpiBayR3d1A4pt4YrPfSdDgpLo
h2SLQqlRqvvVZJaWBjhkErNFpfsBA06sDcPEOb0G8LBUbR4WOcdvhe5LubJbZuxC
AG9kNPCVeQP1ixwjgjXKysaxeQ6rv0VzIQgRp6tLVLWhy6AKDNvLjFSsmXZ1Wl08
Y/RlOHXlzLuQMRE6sR1wOdRxc9TsrNWTGiBK65cvSWOy03JeBkQQ8pesqltiyxI9
U21kkgiXtTSKNGfKK8pO27D81YANhRqPK7iTp6kuFiY2WtOg90KTMNlIT+Ff85Y2
b1rHj6Z0SrCkJujhWk3IBPic/wJgz01LEc/OAdUPlby90RJZcIBhSlWhT7mXnXIO
c0HWlNQrns2s3CTyYwZSiSlYe9ApeLwhjDo8NhbFuCAy61l6O5UsR4AfZxx/rGKv
2wFb1/RN/P4gNe6vmxZAPjR0AQcwD3tc2McimOLr/22kmPz8IH3I0X7WoSFr0Biz
E91G7bb0hOb/cA==
=knv7
-----END PGP PUBLIC KEY BLOCK-----
KEY

echo "🔏 Verifying the signature ..."
# A keyring of its own, so this neither trusts nor pollutes the user's own.
export GNUPGHOME="$TMPDIR/gnupg"
mkdir -m 700 -p "$GNUPGHOME"
gpg --batch --quiet --import "$TMPDIR/aws-cli.pgp"

# --status-fd is what makes this a check rather than a message: gpg prints "Good
# signature" to stderr and exits zero for a signature from any key it happens to hold,
# so the fingerprint has to be compared explicitly against the one pinned above.
status=$(gpg --batch --status-fd 1 --verify "$TMPDIR/awscliv2.sig" "$TMPDIR/awscliv2.zip" 2>/dev/null || true)
if ! grep -q "^\[GNUPG:\] VALIDSIG $FINGERPRINT " <<<"$status"; then
  echo "❌ The AWS CLI download is not signed by $FINGERPRINT -- refusing to install it."
  echo "$status" | sed 's/^/    /'
  exit 1
fi
echo "✔ Signed by the AWS CLI Team key."

unzip -q -u "$TMPDIR/awscliv2.zip" -d "$TMPDIR"

# --update rather than a second install when one is already there; without it the
# installer stops rather than overwrite what it finds.
if [[ -d /usr/local/aws-cli ]]; then
  echo "⬆ Updating the existing installation ..."
  sudo "$TMPDIR/aws/install" --update
else
  sudo "$TMPDIR/aws/install"
fi

echo ""
echo "🎉 Installation Complete!"
aws --version
echo ""
echo "To authenticate, run:"
echo "  aws configure sso     # or: aws configure"
