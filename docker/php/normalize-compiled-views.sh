#!/bin/sh
set -eu

case "$PWD" in
    /var/www/html|/var/www/documentation) runtime_root=$PWD ;;
    *) printf 'unsupported working directory\n' >&2; exit 64 ;;
esac

views_dir="$runtime_root/storage/framework/views"
[ -d "$views_dir" ] || { printf 'compiled views directory is absent\n' >&2; exit 65; }

set -- "$views_dir"/*.php
[ -e "$1" ] || { printf 'no compiled views found\n' >&2; exit 66; }

for compiled_view do
    [ -f "$compiled_view" ] && [ ! -L "$compiled_view" ] || {
        printf 'unexpected compiled view type\n' >&2
        exit 67
    }
done

chmod 0640 -- "$@"
printf 'compiled view modes normalized: %s\n' "$#"
