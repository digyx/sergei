defmodule Sergei.Player do
  use GenServer

  require Logger
  alias Nostrum.Voice

  @check_repeat_interval 100
  @check_empty_interval 30_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :check_repeat, @check_repeat_interval)
    Process.send_after(self(), :check_empty, @check_empty_interval)

    {:ok, state}
  end

  # Client
  def play(guild_id, channel_id, url) do
    GenServer.call(__MODULE__, {:play, guild_id, channel_id, url})
  end

  @spec queue_add(integer(), String.t()) :: :ok | :not_playing
  def queue_add(guild_id, url) do
    GenServer.call(__MODULE__, {:queue_add, guild_id, url})
  end

  @spec queue_clear(integer()) :: :ok | :not_playing
  def queue_clear(guild_id) do
    GenServer.call(__MODULE__, {:queue_clear, guild_id})
  end

  @spec pause(integer()) :: :ok | :not_playing | {:error, String.t()}
  def pause(guild_id) do
    GenServer.call(__MODULE__, {:pause, guild_id})
  end

  @spec resume(integer()) :: :ok | :not_playing | {:error, String.t()}
  def resume(guild_id) do
    GenServer.call(__MODULE__, {:resume, guild_id})
  end

  @spec stop(integer()) :: :ok | :not_playing | {:error, String.t()}
  def stop(guild_id) do
    GenServer.call(__MODULE__, {:stop, guild_id})
  end

  @spec get_current_song(integer()) :: String.t() | :not_playing
  def get_current_song(guild_id) do
    GenServer.call(__MODULE__, {:get_current_song, guild_id})
  end

  # Server
  @impl true
  def handle_info(:check_repeat, state) do
    state
    |> Enum.filter(fn {_id, %{paused: paused} = _state} -> not paused end)
    |> Enum.filter(fn {guild_id, _data} -> not Voice.playing?(guild_id) end)
    |> Enum.map(fn {guild_id, %{queue: queue} = state} ->
      state =
        case :queue.out(queue) do
          {{:value, url}, queue} ->
            %{state | url: url, queue: queue}

          {:empty, _} ->
            state
        end

      {guild_id, state}
    end)
    |> Enum.map(fn {guild_id, %{url: url}} = state ->
      Voice.play(guild_id, url, :ytdl)
      state
    end)

    Process.send_after(self(), :check_repeat, @check_repeat_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_empty, state) do
    Logger.debug("Checking for empty channels")
    %{id: self_id} = Nostrum.Cache.Me.get()

    channel_to_guild =
      state
      |> Map.keys()
      |> Map.new(fn guild_id -> {Voice.get_channel_id(guild_id), guild_id} end)

    populated_channels =
      Sergei.VoiceStateCache.get_state()
      # Filter out self
      |> Enum.filter(fn {user_id, _data} -> user_id != self_id end)
      |> Enum.map(fn {_user_id, %{channel_id: channel_id}} -> channel_id end)
      |> Enum.reduce(MapSet.new(), fn channel, set -> MapSet.put(set, channel) end)

    state
    |> Enum.map(fn {guild_id, _data} -> Voice.get_channel_id(guild_id) end)
    |> Enum.reduce(MapSet.new(), fn channel, set -> MapSet.put(set, channel) end)
    |> MapSet.difference(populated_channels)
    |> Enum.map(fn channel_id ->
      Logger.debug("Leaving channel #{channel_id}")
      channel_id
    end)
    |> Enum.map(fn channel_id -> Map.get(channel_to_guild, channel_id) end)
    |> Enum.each(fn guild_id ->
      Voice.stop(guild_id)
      Voice.leave_channel(guild_id)
    end)

    Process.send_after(self(), :check_empty, @check_empty_interval)
    {:noreply, state}
  end

  # Play
  @impl true
  def handle_call({:play, guild_id, channel_id, url}, _from, state) do
    res = play_music(guild_id, channel_id, url)

    state =
      Map.put(state, guild_id, %{
        url: url,
        paused: false,
        queue: :queue.new()
      })

    {:reply, res, state}
  end

  # Queue
  @impl true
  def handle_call({:queue_add, guild_id, _}, _from, state) when not is_map_key(state, guild_id) do
    {:reply, :not_playing, state}
  end

  @impl true
  def handle_call({:queue_add, guild_id, url}, _from, state) do
    %{queue: queue} = Map.fetch!(state, guild_id)

    {
      :reply,
      :ok,
      Map.update!(
        state,
        guild_id,
        &%{&1 | queue: :queue.in(url, queue)}
      )
    }
  end

  # Guard:  Ensure Sergei is playing something in the guild
  #         All commands below this point assume that this is true
  @impl true
  def handle_call({_, guild_id}, _from, state) when not is_map_key(state, guild_id) do
    {:reply, :not_playing, state}
  end

  # Queue Clear
  @impl true
  def handle_call({:queue_clear, guild_id}, _from, state) do
    {
      :reply,
      :ok,
      Map.update!(
        state,
        guild_id,
        &%{&1 | queue: :queue.new()}
      )
    }
  end

  # Pause
  @impl true
  def handle_call({:pause, guild_id}, _from, state) do
    Voice.pause(guild_id)
    {:reply, :ok, Map.update!(state, guild_id, &%{&1 | paused: true})}
  end

  # Resume
  @impl true
  def handle_call({:resume, guild_id}, _from, state) do
    Voice.resume(guild_id)
    {:reply, :ok, Map.update!(state, guild_id, &%{&1 | paused: false})}
  end

  @impl true
  def handle_call({:stop, guild_id}, _from, state) do
    Voice.stop(guild_id)
    Voice.leave_channel(guild_id)

    {:reply, :ok, Map.delete(state, guild_id)}
  end

  @impl true
  def handle_call({:get_current_song, guild_id}, _from, state) do
    res =
      case Map.get(state, guild_id) do
        %{url: url} -> url
        nil -> :not_playing
        _ -> Logger.error("error: Guild found, but no URL is given")
      end

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
