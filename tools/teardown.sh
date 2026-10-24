#!/usr/bin/env bash
#
# Tears down every Compose project in this lab: the reference stack and all seven cases.
#
#   docker compose down -v --remove-orphans
#
# Scoped by Compose project name (every compose.yaml here declares its own
# `name:`), so this touches only this lab's containers, volumes and networks.
#
# There is deliberately NO `docker system prune` here, and there never should
# be. Deleting somebody's unrelated Docker state is not this repo's business.
#
# -v deletes the lab's volumes, so every case comes back cold and re-seeds from
# scratch on the next ./setup.sh. That is the point.
#
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

echo "Tearing down every Compose project in this lab (containers, volumes, networks)."
echo

down() { # $1 = directory, $2... = extra compose args
  local dir=$1; shift
  ( cd "$dir" && docker compose "$@" down -v --remove-orphans ) 2>&1 \
    | grep -E 'Removing|Removed|Warning|error|Error' \
    | sed 's/^/    /'
  return 0
}

# The reference stack.
if [ -f "$ROOT/reference/compose.yaml" ]; then
  echo "reference/"
  down "$ROOT/reference"
fi

# Every case.
for dir in "$ROOT"/cases/*/; do
  [ -f "$dir/compose.yaml" ] || continue
  echo "cases/$(basename "$dir")/"

  for nested in "$dir"*/compose.yaml; do
    [ -f "$nested" ] || continue
    rel=${nested#"$dir"}
    echo "  ($rel)"
    down "$dir" -f "$rel"
  done

  down "$dir"
done

echo
echo "Anything of this lab's still standing? (should be nothing)"
remaining=$(docker ps -a --filter name=inslab --format '{{.Names}} ({{.Status}})')
if [ -n "$remaining" ]; then
  echo "$remaining" | sed 's/^/    /'
else
  echo "    no inslab-* containers"
fi
vols=$(docker volume ls --filter name=inslab --format '{{.Name}}')
if [ -n "$vols" ]; then
  echo "    volumes still present:"
  echo "$vols" | sed 's/^/      /'
  echo "    (a volume Compose no longer references survives \`down -v\`, remove it with"
  echo "     docker volume rm <name>. It is state that outlived its configuration.)"
else
  echo "    no inslab-* volumes"
fi

echo
echo "Done. Your unrelated containers, images and volumes were not touched."

