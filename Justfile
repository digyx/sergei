set dotenv-load

deploy:
    docker build -t godmaire/sergei:latest
    docker tag godmaire/sergei:latest registry.digitalocean.com/godmaire/sergei:latest
    docker push registry.digitalocean.com/godmaire/sergei:latest

run:
    mix deps.get
    DISCORD_TOK=$DISCORD_TOK mix run --no-halt
