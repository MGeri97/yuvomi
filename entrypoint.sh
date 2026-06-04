#!/bin/sh
# Entrypoint: Volume-Permissions zur Laufzeit korrigieren, dann als node-User starten.
# Notwendig, weil Docker beim Mounten eines named Volume die Image-Permissions überschreibt.
# Der chown läuft nur als root: TrueNAS setzt Ownership optional über einen eigenen
# Permissions-Container (568:568) und startet den App-Container dann ohne root —
# in diesem Fall wird der chown übersprungen.
set -e
[ "$(id -u)" = "0" ] && chown -R node:node /data /backups /app/modules
exec gosu node "$@"
