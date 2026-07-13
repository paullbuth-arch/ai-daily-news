#!/bin/sh
# Minimal wrapper: requires a local Gradle installation in PATH.
# For full wrapper support, run: gradle wrapper --gradle-version 8.2
exec gradle "$@"
