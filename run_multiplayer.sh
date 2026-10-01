#!/bin/bash
# Run Dotline Duel with multiplayer enabled.
# Usage: bash run_multiplayer.sh
#   or:  bash run_multiplayer.sh --release
#
# Requires a .env file in this directory with:
#   SUPABASE_URL=https://xxxx.supabase.co
#   SUPABASE_ANON_KEY=eyJ...

set -e

ENV_FILE="$(dirname "$0")/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found."
  echo "Create one based on .env.example:"
  echo "  cp .env.example .env"
  echo "Then fill in your Supabase URL and anon key."
  exit 1
fi

# Load variables from .env (skip comments and blank lines).
while IFS='=' read -r key value; do
  case "$key" in
    '#'*|'') continue ;;
  esac
  export "$key=$value"
done < "$ENV_FILE"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env"
  exit 1
fi

flutter run "$@" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
