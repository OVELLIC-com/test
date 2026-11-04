#!/usr/bin/env bash
# .github/scripts/attach-signatures.sh DIR TAG CA_FILE
#
# Attaches the detached Windows signatures published for TAG on the
# `signatures` branch to the binaries this run built, then repacks the npm
# packages in DIR from the signed binaries.
#
# A signature only fits the exact bytes it was made over, so each binary built
# here must be byte-identical to the one that was signed: its sha256 has to equal
# the manifest's unsigned_sha256, or the run stops. There is no fallback to
# publishing unsigned binaries once signatures exist for the version.
#
# Without a signatures entry for TAG the packages are left as built (unsigned).
set -euo pipefail

dir="${1:?usage: attach-signatures.sh DIR TAG CA_FILE}"
tag="${2:?usage: attach-signatures.sh DIR TAG CA_FILE}"
ca="${3:?usage: attach-signatures.sh DIR TAG CA_FILE}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

auth=()
if [ -n "${GH_TOKEN:-}" ]; then
  auth=(-c "http.https://github.com/.extraheader=AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')")
fi
if ! git "${auth[@]}" fetch --quiet --depth 1 origin "+refs/heads/signatures:refs/remotes/origin/signatures" 2>/dev/null \
  || ! git cat-file -e "refs/remotes/origin/signatures:$tag/manifest.json" 2>/dev/null; then
  echo "no signatures for $tag; the packages stay unsigned" >&2
  exit 0
fi
git archive "refs/remotes/origin/signatures" "$tag" | tar -x -C "$work"
manifest="$work/$tag/manifest.json"

head="$(git rev-parse HEAD)"
read -r recorded <<<"$(node -e 'process.stdout.write(require(process.argv[1]).commit)' "$manifest")"
if [ "$recorded" != "$head" ]; then
  echo "error: the signatures for $tag were made for $recorded, this run built $head" >&2
  exit 1
fi

signed_dir="$root/dist/signed-binaries"
rm -rf "$signed_dir"
cp -R "$dir/binaries" "$signed_dir"

entries="$(node -e '
  const m = require(process.argv[1]);
  for (const [id, b] of Object.entries(m.binaries)) console.log([id, b.unsigned_sha256, b.signed_sha256, b.sig].join(" "));
' "$manifest")"
while read -r id unsigned_sha signed_sha sig; do
  [ -n "$id" ] || continue
  exe="$(ls "$dir/binaries/$id/"*.exe)"
  actual="$(sha256sum "$exe" | cut -d' ' -f1)"
  if [ "$actual" != "$unsigned_sha" ]; then
    echo "error: $id built as $actual here, but $unsigned_sha was signed" >&2
    echo "  the two builds are not byte-identical; check the Go version and build flags" >&2
    exit 1
  fi
  out="$signed_dir/$id/$(basename "$exe")"
  rm -f "$out"
  osslsigncode attach-signature -sigin "$work/$tag/$sig" -CAfile "$ca" -in "$exe" -out "$out" >/dev/null
  osslsigncode verify -in "$out" -CAfile "$ca" >"$work/verify-$id.log" 2>&1 || {
    cat "$work/verify-$id.log" >&2
    echo "error: the attached signature of $id does not verify" >&2
    exit 1
  }
  got="$(sha256sum "$out" | cut -d' ' -f1)"
  if [ "$got" = "$signed_sha" ]; then
    echo "$id: signed, byte-identical to the file that was signed" >&2
  else
    echo "$id: signed and verified; differs from the signed original ($got vs $signed_sha)" >&2
  fi
done <<EOF
$entries
EOF

# Repack from the signed binaries. The kit empties its output directory first,
# which is why the binaries were copied out of it.
node "$root/npmkit/package.mjs" --product "$root/npm/product.json" --output "$dir" --skip-build --binaries-dir "$signed_dir"
