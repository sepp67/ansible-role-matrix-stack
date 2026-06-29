#!/bin/sh
# Entrypoint Synapse avec installation de la CA Caddy interne (staging).
# Ce script est monté en lecture seule dans le conteneur.
# Il installe le certificat CA dans le trust store système puis délègue
# immédiatement au start.py officiel, en transmettant tous les arguments
# originaux (CMD Docker = "start").
set -e

update-ca-certificates

exec /start.py "$@"
