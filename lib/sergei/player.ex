defmodule Sergei.Player do
  use GenServer

  require Logger
  alias Nostrum.Voice

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :tick, 100)

    {:ok, state}
  end

  # Client
  def play(guild_id, channel_id, url) do
    GenServer.call(__MODULE__, {:play, guild_id, channel_id, url})
  end

  # Server
  @impl true
  def handle_info(:tick, state) do
    state
    |> Enum.filter(fn {_id, %{paused: paused} = _state} -> not paused end)
    |> Enum.filter(fn {guild_id, _data} -> not Voice.playing?(guild_id) end)
    |> Enum.each(fn {guild_id, %{url: url}} = _state ->
      Voice.play(guild_id, url, :ytdl)
    end)

    Process.send_after(self(), :tick, 100)
    {:noreply, state}
  end

  @impl true
  def handle_call({:play, guild_id, channel_id, url}, _from, state) do
    res = play_music(guild_id, channel_id, url)

    state =
      Map.put(state, guild_id, %{
        url: url,
        paused: false
      })

    {:reply, res, state}
  end

  def play_music(guild_id, channel_id, url) do
    cond do
      Voice.get_channel_id(guild_id) != channel_id ->
        Logger.debug("Changing channels...")

        Voice.leave_channel(guild_id)
        Voice.join_channel(guild_id, channel_id)

        # Wait for the client to finish joining the voice channel
        # TODO: check the channel ID in a loop instead
        Process.sleep(500)

        play_music(guild_id, channel_id, url)

      Voice.playing?(guild_id) ->
        Logger.debug("Stopping playback...")

        Voice.stop(guild_id)
        play_music(guild_id, channel_id, url)

      Voice.ready?(guild_id) ->
        case Voice.play(guild_id, url, :ytdl) do
          :ok ->
            Logger.info("Playing #{url}")
            {:ok, "Playing music..."}

          {:error, res} ->
            Logger.error("Could not play music: #{res}")
            {:error, "Fuck..."}
        end

      true ->
        Logger.debug("Waiting...")
        Process.sleep(500)
        play_music(guild_id, channel_id, url)
    end
  end
end
