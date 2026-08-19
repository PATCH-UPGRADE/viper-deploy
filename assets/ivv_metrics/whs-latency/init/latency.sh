#!/usr/bin/env bash
# Just latency             -> quiet ping (per-packet output suppressed, summary only)
# Just latency --verbose   -> full per-packet output
set -uo pipefail

ARGS=(-c 10 -i 0.5 -4 -n)
EXTRA=()
for a in "$@"; do
  if [[ "$a" == "--verbose" ]]; then
    VERBOSE=1
  else
    EXTRA+=("$a")
  fi
done
[[ "${VERBOSE:-0}" == "1" ]] || ARGS+=(-q)

podman exec whs ping "${ARGS[@]}" "${EXTRA[@]}" real.whs.local
podman exec whs ping "${ARGS[@]}" "${EXTRA[@]}" simulated.whs.local
