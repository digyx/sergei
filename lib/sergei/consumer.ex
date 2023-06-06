defmodule Sergei.Consumer do
  use Nostrum.Consumer

  require Logger
  alias Nostrum.Api

  # Translate params to list of maps
  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @play_opts [
    opt.(3, "url", "URL of the audio to play", required: true)
  ]

  @slash_commands [
    {"ping", "Pong", []},
    {"pause", "Pause media playback", []},
    {"resume", "Resume media playback", []},
    {"play", "Play some tunes", @play_opts}
  ]

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Bulk overwrite commands per guild.  While this is efficient enough for now, moving
  # to global commands in the future is probably a good idea.
  @spec register_commands!(integer) :: :ok
  def register_commands!(guild_id) do
    commands =
      Enum.map(@slash_commands, fn {name, description, options} ->
        %{
          name: name,
          description: description,
          options: options
        }
      end)

    case Api.bulk_overwrite_guild_application_commands(guild_id, commands) do
      {:ok, _res} -> :ok
      {:error, err} -> raise err
    end
  end

  # Initialization of the Discord Client
  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    Api.update_status(:online, "some tunes", 0)

    guilds
    |> Enum.map(fn guild -> guild.id end)
    |> Enum.each(&register_commands!/1)
  end

  def handle_event({:VOICE_STATE_UPDATE, state, _ws_state}) do
    Sergei.VoiceStateCache.update_state(state)
  end

  # Handle interactions
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    response =
      case do_command(interaction) do
        {:ok, msg} ->
          %{type: 4, data: %{content: msg, flags: 2 ** 6}}

        {:error, msg} ->
          %{type: 4, data: %{content: msg, flags: 2 ** 6}}
      end

    Api.create_interaction_response!(interaction, response)
  end

  # Ignore other events
  def handle_event(_event) do
    :noop
  end

  # /ping
  def do_command(%{data: %{name: "ping"}}) do
    {:ok, "Pong"}
  end

  # /play <url>
  def do_command(
        %{
          guild_id: guild_id,
          member: %{user: %{id: invoker_id}},
          data: %{name: "play", options: opts}
        } = _interaction
      ) do
    [%{name: "url", value: url}] = opts

    case Sergei.VoiceStateCache.get_state(invoker_id) do
      %{guild_id: id} = _res when guild_id != id ->
        {:error, "You're not connected to a voice channel in this server."}

      %{channel_id: channel_id} = _res ->
        Sergei.Player.play(guild_id, channel_id, url)

      nil ->
        {:error, "You are not in a voice channel."}
    end
  end

  # /pause
  def do_command(%{guild_id: guild_id, data: %{name: "pause"}}) do
    case Sergei.Player.pause(guild_id) do
      :ok ->
        {:ok, "Pausing..."}

      {:error, err} ->
        Logger.error("Failed to pause media: #{err}")
        {:error, "This is embarrasing..."}
    end
  end

  # /resume
  def do_command(%{guild_id: guild_id, data: %{name: "resume"}}) do
    case Sergei.Player.resume(guild_id) do
      :ok ->
        {:ok, "Resuming..."}

      {:error, err} ->
        Logger.error("Failed to resume media: #{err}")
        {:error, "This is embarrasing..."}
    end
  end
end
