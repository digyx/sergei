set dotenv-load

build:
    podman build -t git.scalio.me/digyx/sergei:latest .

deploy: build
    podman push git.scalio.me/digyx/sergei:latest

run:
    mix deps.get
    DISCORD_TOK=$DISCORD_TOK mix run --no-halt
