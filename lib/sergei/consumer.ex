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
    opt.(3, "url", "URL of the audio to play", [])
  ]

  @slash_commands [
    {"ping", "Pong", []},
    {"play", "Play a song or resume playback", @play_opts},
    {"pause", "Pause media playback", []},
    {"stop", "Stop media playback and leave the voice channel", []}
  ]

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Initialization of the Discord Client
  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    # Playing some tunes
    Api.update_status(:online, "some tunes", 0)

    commands =
      Enum.map(@slash_commands, fn {name, description, options} ->
        %{
          name: name,
          description: description,
          options: options
        }
      end)

    case Application.get_env(:sergei, :env) do
      :prod ->
        case Api.bulk_overwrite_global_application_commands(commands) do
          {:ok, _res} -> :ok
          {:error, err} -> raise err
        end

      # Overwrite commands by guild in dev for a faster dev cycle
      :dev ->
        guilds
        |> Enum.map(fn guild -> guild.id end)
        |> Enum.each(fn guild_id ->
          case Api.bulk_overwrite_guild_application_commands(guild_id, commands) do
            {:ok, _res} -> :ok
            {:error, err} -> raise err
          end
        end)

      _ ->
        Logger.error("invalid environment:  expected dev or prod")
        System.stop(1)
    end
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
          %{
            type: 4,
            data: %{
              content: "error: #{msg}",
              flags: 2 ** 6
            }
          }
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
  def do_command(%{
        guild_id: guild_id,
        member: %{user: %{id: invoker_id}},
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
end
