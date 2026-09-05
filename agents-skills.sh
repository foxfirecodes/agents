#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/agents/skills"
target_dir="${HOME}/.agents/skills"

if [[ ! -d "$source_dir" ]]; then
	printf 'No skills directory found at %s\n' "$source_dir" >&2
	exit 1
fi

mkdir -p "$target_dir"

for skill_dir in "$source_dir"/*/; do
	[[ -d "$skill_dir" ]] || continue

	skill_name="$(basename "$skill_dir")"
	target="$target_dir/$skill_name"

	if [[ -e "$target" || -L "$target" ]]; then
		printf 'Skipping %s: %s already exists\n' "$skill_name" "$target"
		continue
	fi

	ln -s "$skill_dir" "$target"
	printf 'Linked %s\n' "$skill_name"
done
