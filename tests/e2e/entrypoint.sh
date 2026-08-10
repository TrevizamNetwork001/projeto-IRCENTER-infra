#!/bin/sh
set -eu

node /work/support/guardrails.js
exec "$@"
