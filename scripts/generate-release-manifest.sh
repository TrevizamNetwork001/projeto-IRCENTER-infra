#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUTPUT=${1:-"$ROOT_DIR/release-manifest.local.env"}
RELEASE_VERSION=${RELEASE_VERSION:-hardening-audit}

git_head() {
    repository=$1
    git -c safe.directory="$repository" -C "$repository" rev-parse HEAD
}

image_id() {
    docker image inspect --format '{{.Id}}' "$1" 2>/dev/null || printf NOT_BUILT
}

{
    printf 'release_version=%s\n' "$RELEASE_VERSION"
    printf 'build_timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'infra_commit=%s\n' "$(git_head "$ROOT_DIR")"
    printf 'core_commit=%s\n' "$(git_head "$ROOT_DIR/app")"
    printf 'documentation_commit=%s\n' "$(git_head "$ROOT_DIR/documentation-app")"
    printf 'infra_dirty=%s\n' "$([ -z "$(git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" status --porcelain)" ] && echo no || echo yes)"
    printf 'core_dirty=%s\n' "$([ -z "$(git -c safe.directory="$ROOT_DIR/app" -C "$ROOT_DIR/app" status --porcelain)" ] && echo no || echo yes)"
    printf 'documentation_dirty=%s\n' "$([ -z "$(git -c safe.directory="$ROOT_DIR/documentation-app" -C "$ROOT_DIR/documentation-app" status --porcelain)" ] && echo no || echo yes)"
    printf 'core_image_id=%s\n' "$(image_id "ircenter-core:$RELEASE_VERSION")"
    printf 'documentation_image_id=%s\n' "$(image_id "ircenter-documentation:$RELEASE_VERSION")"
    printf 'web_image_id=%s\n' "$(image_id "ircenter-web:$RELEASE_VERSION")"
    printf 'core_migrations=%s\n' "$(find "$ROOT_DIR/app/database/migrations" -maxdepth 1 -type f -printf '%f,' | sort | tr -d '\n')"
    printf 'documentation_migrations=%s\n' "$(find "$ROOT_DIR/documentation-app/database/migrations" -maxdepth 1 -type f -printf '%f,' | sort | tr -d '\n')"
} > "$OUTPUT"
chmod 0600 "$OUTPUT"
printf 'manifest=%s\n' "$OUTPUT"
