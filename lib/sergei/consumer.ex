defmodule Sergei.Consumer do
  use Nostrum.Consumer

  require Logger
  alias Nostrum.Api

  # Initialization of the Discord Client
  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    # Playing some tunes
    Api.update_status(:online, "some tunes", 0)

    commands = Sergei.Commands.commands()

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
      case Sergei.Commands.do_command(interaction) do
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
end
