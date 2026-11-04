#!/usr/bin/env bash
# .github/scripts/publish.sh DIR
#
# Publishes the npm packages a release build left in DIR (its
# release-manifest.json and tarballs/) to the registry npm is configured for,
# under the `latest` dist-tag.
#
# Platform packages go first and the main package last: the main package pins
# each platform package to this exact version, so a run that fails part-way can
# only leave platform packages behind, which nothing installs on its own.
#
# Re-running is safe. A package already on the registry at this version is
# skipped when its integrity matches the tarball here, which is what a repeated
# run of the same release looks like. A mismatch means the version was published
# from somewhere else, and the run stops rather than mixing the two.
#
# Authentication is npm's business: in the release workflow it is trusted
# publishing (OIDC), so no token is read or needed here.
set -euo pipefail

dir="${1:?usage: publish.sh DIR}"
manifest="$dir/release-manifest.json"
[ -f "$manifest" ] || { echo "error: no release manifest at $manifest" >&2; exit 1; }

# One line per package, main last: name, version, tarball file, integrity.
packages="$(node -e '
  const m = require(require("path").resolve(process.argv[1]));
  const ordered = [...m.packages].sort((a, b) => (a.name === m.product) - (b.name === m.product));
  for (const p of ordered) console.log([p.name, p.version, p.filename, p.integrity].join(" "));
' "$manifest")"

published=0
skipped=0
while read -r name version filename integrity; do
  [ -n "$name" ] || continue
  existing="$(npm view "$name@$version" dist.integrity 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    if [ "$existing" != "$integrity" ]; then
      echo "error: $name@$version is already on the registry with different content" >&2
      echo "  registry: $existing" >&2
      echo "  this run: $integrity" >&2
      echo "  the version was published from somewhere else; release under the next version" >&2
      exit 1
    fi
    echo "skip $name@$version (already published, same content)" >&2
    skipped=$((skipped + 1))
    continue
  fi
  npm publish "$dir/tarballs/$filename" --tag latest --access public
  published=$((published + 1))
done <<EOF
$packages
EOF

echo "published $published, skipped $skipped" >&2
