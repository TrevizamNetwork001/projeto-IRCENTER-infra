#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
default_files="
$root_dir/compose.yaml
$root_dir/compose.test.yaml
$root_dir/compose.healthcheck.test.yaml
$root_dir/docker/php/Dockerfile
$root_dir/docker/test/Dockerfile
"
if [ "$#" -gt 0 ]; then
    files="$*"
else
    files="$default_files"
fi

failed=0
report() {
    printf 'VIOLACAO: %s\n' "$1" >&2
    failed=1
}

references=$(
    awk '
        /^[[:space:]]*image:[[:space:]]*/ {
            value = $0
            sub(/^[[:space:]]*image:[[:space:]]*/, "", value)
            gsub(/["'\'' ]/, "", value)
            print value
        }
        /^[[:space:]]*FROM[[:space:]]+/ { print $2 }
        /COPY[[:space:]]+--from=/ {
            value = $0
            sub(/^.*--from=/, "", value)
            sub(/[[:space:]].*$/, "", value)
            print value
        }
    ' $files
)

for reference in $references; do
    case "$reference" in
        *:latest|*:latest@*)
            report "tag latest: $reference"
            ;;
        nginx:alpine|nginx:alpine@*|composer:2|composer:2@*)
            report "tag flutuante conhecida: $reference"
            ;;
        ircenter-*:*)
            # Artefato local gerado pelo build declarado no mesmo Compose.
            ;;
        *@sha256:*)
            digest=${reference##*@sha256:}
            case "$digest" in
                *[!0-9a-f]*|'') report "digest invalido: $reference" ;;
            esac
            [ "${#digest}" -eq 64 ] \
                || report "digest deve possuir 64 hexadecimais: $reference"
            ;;
        *)
            report "imagem externa sem digest: $reference"
            ;;
    esac
done

[ "$failed" -eq 0 ] || exit 1
printf 'OK: referencias externas usam versao explicita e digest.\n'
