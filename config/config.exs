import Config

config :nostrum,
  youtubedl: "/usr/bin/yt-dlp"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
