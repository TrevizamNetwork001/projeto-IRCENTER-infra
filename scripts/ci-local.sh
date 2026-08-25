#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

export COMPOSE_DISABLE_ENV_FILE=1
export FINANCE_ENABLED=false
export PAYMENT_PROVIDER=fake
export PAYMENT_LIVE_ENABLED=false
export PAYMENT_WEBHOOKS_ENABLED=false
export FINANCE_AUTOMATION_ENABLED=false
export FISCAL_ENABLED=false
export FISCAL_PROVIDER=fake
export NFSE_PROVIDER=fake
export NFSE_TRANSMISSION_ENABLED=false
export NFSE_LIVE_ENABLED=false
export EFI_ENVIRONMENT=homologation

INFRA_COMMIT=$(git -c safe.directory="$ROOT_DIR" rev-parse HEAD)
CORE_COMMIT=$(git -c safe.directory="$ROOT_DIR/app" -C app rev-parse HEAD)
DOCUMENTATION_COMMIT=$(git -c safe.directory="$ROOT_DIR/documentation-app" -C documentation-app rev-parse HEAD)
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RELEASE_VERSION=${RELEASE_VERSION:-ci-${GITHUB_SHA:-local}}
export INFRA_COMMIT CORE_COMMIT DOCUMENTATION_COMMIT BUILD_DATE RELEASE_VERSION
export INFRA_REPOSITORY=${INFRA_REPOSITORY:-local/ircenter-infra}
export CORE_REPOSITORY=${CORE_REPOSITORY:-local/ircenter-core}
export DOCUMENTATION_REPOSITORY=${DOCUMENTATION_REPOSITORY:-local/ircenter-documentation}
export SOURCE_TREE_DIGEST=${SOURCE_TREE_DIGEST:-$INFRA_COMMIT}
export CORE_SOURCE_TREE_DIGEST=${CORE_SOURCE_TREE_DIGEST:-$CORE_COMMIT}
export DOCUMENTATION_SOURCE_TREE_DIGEST=${DOCUMENTATION_SOURCE_TREE_DIGEST:-$DOCUMENTATION_COMMIT}
export POSTGRES_DB=ci POSTGRES_USER=ci POSTGRES_PASSWORD=ci-isolated-only

docker compose --env-file /dev/null -f compose.test.yaml config --quiet
docker compose --env-file /dev/null -f compose.e2e.test.yaml config --quiet
docker compose --env-file /dev/null -f compose.healthcheck.test.yaml config --quiet
docker compose --env-file /dev/null -f compose.hardened.yaml config --quiet --no-env-resolution

./scripts/check-build-context.sh
./scripts/check-container-images.sh
./scripts/secret-scan.sh
./scripts/test-isolated.sh app test
./scripts/test-isolated.sh documentation test
./scripts/test-e2e.sh

docker run --rm --network none --entrypoint composer \
    ircenter-app-test:h1 validate --strict --no-check-publish
docker run --rm --network none --entrypoint composer \
    ircenter-documentation-test:h1 validate --strict --no-check-publish
docker run --rm --entrypoint composer \
    ircenter-app-test:h1 audit --locked --no-interaction
docker run --rm --entrypoint composer \
    ircenter-documentation-test:h1 audit --locked --no-interaction
docker run --rm --entrypoint npm \
    ircenter-e2e-runner:h11 audit --audit-level=high

docker compose --env-file /dev/null -f compose.hardened.yaml build app documentation-app web

docker run --rm --network none --entrypoint sh "ircenter-core:$RELEASE_VERSION" -c \
    'test "$(id -u)" -ne 0; test -r /app-release.json; test ! -e /usr/local/bin/composer; test ! -e /usr/bin/git'
docker run --rm --network none --entrypoint sh "ircenter-documentation:$RELEASE_VERSION" -c \
    'test "$(id -u)" -ne 0; test -r /app-release.json; test ! -e /usr/local/bin/composer; test ! -e /usr/bin/git'

printf 'CI_LOCAL=PASS\n'
