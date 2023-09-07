set dotenv-load

version := `cat mix.exs | grep version | sed -e 's/.*version: "\(.*\)",/\1/'`

# Build a podman container
build:
    podman build -t sergei:dev .

# Deploy latest to codeberg
deploy: build
    podman push sergei:dev codeberg.org/godmaire/sergei:latest

# Create a release for the specified version
release: build
    #!/usr/bin/env bash
    set -euo pipefail

    read -p "Are you sure you want to release? [y/N]: " choice
    [[ "$choice" == [Yy] ]] && echo "Releasing..." || exit 0

    git tag -a v{{version}} -m "Release for version {{version}}"
    git push --follow-tags

    podman push sergei:dev codeberg.org/godmaire/sergei:latest
    podman push sergei:dev codeberg.org/godmaire/sergei:{{version}}

# Run locally via elixir
# This requires yt-dlp to be installed
run:
    mix deps.get
    DISCORD_TOK=$DISCORD_TOK mix run --no-halt

run-docker: build
  podman run -e DISCORD_TOK=$DISCORD_TOK sergei:dev
