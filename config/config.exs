import Config

config :nostrum,
  youtubedl: "/usr/bin/yt-dlp"

config :sergei,
  env: config_env()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
