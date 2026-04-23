#!/usr/bin/env bash

log()   { printf '[%s] %s\n'   "$(date +%H:%M:%S)" "$*"; }
ok()    { printf '[%s] ✓ %s\n' "$(date +%H:%M:%S)" "$*"; }
warn()  { printf '[%s] ⚠ %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
error() { printf '[%s] ✗ %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
