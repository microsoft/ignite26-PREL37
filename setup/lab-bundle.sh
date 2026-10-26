#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

cd "$(dirname "${BASH_SOURCE[0]}")/.."
for tool in git tar zip; do
  command -v "$tool" >/dev/null ||
    { printf 'Missing %s. Install it before creating a lab bundle.\n' "$tool" >&2; exit 1; }
done
[ ! -e .lab-bundle ] ||
  { printf 'Create bundles from the authoring Git checkout, not an extracted bundle.\n' >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=normal)" ] ||
  { printf 'Commit the intended lab changes and move unrelated untracked files aside before bundling. Only committed files are packaged.\n' >&2; exit 1; }

revision="$(git rev-parse HEAD)"
destination="$(mktemp -d /tmp/prel37-lab-bundle.XXXXXX)"
trap 'printf "Bundle creation failed. Inspect the partial output at %s; do not distribute it.\n" "$destination" >&2' ERR
mkdir "$destination/setup"
git archive "$revision" | tar -x -C "$destination/setup"
printf '%s\n' "$revision" > "$destination/setup/.lab-bundle"
(
  cd "$destination"
  zip -qr prel37-lab-bundle.zip setup
)
printf 'Source revision: %s\nFolder: %s/setup\nZIP: %s/prel37-lab-bundle.zip\n' "$revision" "$destination" "$destination"
printf 'Extract the ZIP in WSL under $HOME/prel37, then run make setup from $HOME/prel37/setup.\n'
