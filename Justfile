set dotenv-load

build:
    podman build -t codeberg.org/godmaire/sergei:latest .

deploy: build
    podman push codeberg.org/godmaire/sergei:latest

run:
    mix deps.get
    DISCORD_TOK=$DISCORD_TOK mix run --no-halt
