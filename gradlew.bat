@echo off
REM Minimal wrapper: requires a local Gradle installation in PATH.
REM For full wrapper support, run: gradle wrapper --gradle-version 8.2
gradle %*
