set dotenv-load

build:
    docker build -t digyx/sergei:latest .

deploy: build
    docker push digyx/sergei:latest

run:
    mix deps.get
    DISCORD_TOK=$DISCORD_TOK mix run --no-halt
