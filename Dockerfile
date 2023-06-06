FROM elixir:alpine AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./
COPY config ./config

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sergei

FROM alpine:3.16

WORKDIR /opt/sergei
RUN apk add ffmpeg yt-dlp
RUN apk add \
    --update \
    --no-cache \
    libstdc++ ncurses openssl
COPY --from=build_stage /opt/build/_build/prod/rel/sergei /opt/sergei

ENTRYPOINT ["/opt/sergei/bin/sergei"]
CMD ["start"]
