defmodule Sergei.Commands do
  require Logger

  # Translate params to list of maps
  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @play_opts [
    opt.(3, "url", "URL of the audio to play", [])
  ]

  @queue_add_opts [
    opt.(3, "url", "URL of the audio to queue", required: true)
  ]

  @queue_opts [
    opt.(1, "add", "Add a song to the queue", options: @queue_add_opts)
  ]

  @slash_commands [
    {"ping", "Pong", []},
    {"play", "Play a song or resume playback", @play_opts},
    {"queue", "Manage the song queue", @queue_opts},
    {"pause", "Pause media playback", []},
    {"stop", "Stop media playback and leave the voice channel", []},
    {"song", "What song is currently playing?", []}
  ]

  def commands() do
    Enum.map(@slash_commands, fn {name, description, options} ->
      %{
        name: name,
        description: description,
        options: options
      }
    end)
  end

  # /ping
  def do_command(%{data: %{name: "ping"}}) do
    {:ok, "Pong"}
  end

  # /play <url>
  def do_command(%{
        guild_id: guild_id,
        user: %{id: invoker_id},
        data: %{name: "play", options: [%{name: "url", value: url}]}
      }) do
    case Sergei.VoiceStateCache.get_state(invoker_id) do
      %{guild_id: id} = _res when guild_id != id ->
        {:error, "You're not connected to a voice channel in this server."}

      %{channel_id: channel_id} = _res ->
        Sergei.Player.play(guild_id, channel_id, url)

      nil ->
        {:error, "You are not in a voice channel."}
    end
  end

  # /play
  def do_command(%{guild_id: guild_id, data: %{name: "play"}}) do
    case Sergei.Player.resume(guild_id) do
      :ok ->
        {:ok, "Resuming playback..."}

      :not_playing ->
        {:ok, "I'm not playing anything right now."}

      {:error, err} ->
        Logger.error("Failed to resume media: #{err}")
        {:error, "This is embarrasing..."}
    end
  end

  # /queue <subcommand>
  def do_command(%{
        guild_id: guild_id,
        data: %{name: "queue", options: opts}
      }) do
    subcommand = List.first(opts)

    Sergei.Commands.Queue.handle(guild_id, subcommand.name, subcommand.options)
  end

  # /pause
  def do_command(%{guild_id: guild_id, data: %{name: "pause"}}) do
    case Sergei.Player.pause(guild_id) do
      :ok ->
        {:ok, "Pausing..."}

      :not_playing ->
        {:ok, "I'm not playing anything right now."}

      {:error, err} ->
        Logger.error("Failed to pause media: #{err}")
        {:error, "This is embarrasing..."}
    end
  end

  # /stop
  def do_command(%{guild_id: guild_id, data: %{name: "stop"}}) do
    case Sergei.Player.stop(guild_id) do
      :ok ->
        {:ok, "Bye!"}

      :not_playing ->
        {:ok, "I'm not playing anything right now."}

      {:error, err} ->
        Logger.error("Failed to stop media: #{err}")
        {:error, "This is embarrasing..."}
    end
  end

  # /song
  def do_command(%{guild_id: guild_id, data: %{name: "song"}}) do
    case Sergei.Player.get_current_song(guild_id) do
      :not_playing ->
        {:ok, "I'm not playing anything right now."}

      url ->
        {:ok, url}
    end
  end
end
