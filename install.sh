#!/usr/bin/env bash
#
# install.sh — fetch start-hy2's dependencies into this folder. No root needed.
#
# Pulls:
#   * the latest Hysteria 2 binary  -> ./bin/hysteria
#   * upnpc + qrencode (+ their libs) extracted from Debian/Ubuntu .deb packages
#                                     -> ./local/...
#
# Requires: curl, openssl, screen, gcc-less — and `apt-get`/`dpkg-deb` (Debian/
# Ubuntu) for the upnpc/qrencode helpers. Re-run any time to update Hysteria.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

case "$(uname -m)" in
  x86_64)  HYARCH=amd64 ;;
  aarch64) HYARCH=arm64 ;;
  armv7l)  HYARCH=arm   ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

for c in curl apt-get dpkg-deb; do
  command -v "$c" >/dev/null || { echo "missing required tool: $c" >&2; exit 1; }
done

echo "==> Fetching latest Hysteria 2 ($HYARCH)..."
TAG="$(curl -fsSL https://api.github.com/repos/apernet/hysteria/releases/latest \
        | grep -m1 '"tag_name"' | cut -d'"' -f4)"
[ -n "$TAG" ] || { echo "could not resolve latest Hysteria release" >&2; exit 1; }
mkdir -p bin
curl -fSL --retry 3 --retry-delay 2 -o bin/hysteria \
  "https://github.com/apernet/hysteria/releases/download/${TAG}/hysteria-linux-${HYARCH}"
chmod +x bin/hysteria
echo "    Hysteria ${TAG} installed."

echo "==> Fetching upnpc + qrencode (rootless, via apt-get download)..."
# Resolve the versioned library package names for this distro release.
LIBMINI="$(apt-cache depends miniupnpc 2>/dev/null | awk '/Depends:.*libminiupnpc/{print $2; exit}')"
LIBQR="$(apt-cache depends qrencode  2>/dev/null | awk '/Depends:.*libqrencode/{print $2; exit}')"
rm -rf pkg local
mkdir -p pkg local
( cd pkg && apt-get download miniupnpc ${LIBMINI:-} qrencode ${LIBQR:-} )
for d in pkg/*.deb; do dpkg-deb -x "$d" local; done
rm -rf pkg

[ -x local/usr/bin/upnpc ]   || { echo "upnpc not found after extract" >&2; exit 1; }
[ -x local/usr/bin/qrencode ] || echo "    (qrencode missing — QR codes will be skipped)"

echo
echo "Done. Start the proxy with:"
echo "    screen -S hy2 ./start-hy2"
