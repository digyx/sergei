defmodule Sergei.VoiceStateCache do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(cache) do
    {:ok, cache}
  end

  # Client
  @spec update_state(Nostrum.Struct.Event.VoiceState.t()) :: :ok
  def update_state(state) do
    GenServer.cast(__MODULE__, {:update, state})
  end

  @spec get_state(non_neg_integer()) :: %{guild_id: integer(), channel_id: integer()} | nil
  def get_state(user_id) do
    GenServer.call(__MODULE__, {:get, user_id})
  end

  # Server
  @impl true
  def handle_cast({:update, state}, cache) do
    %{
      guild_id: guild_id,
      channel_id: channel_id,
      member: %{
        user: %{
          id: user_id
        }
      }
    } = state

    entry =
      Map.new()
      |> Map.put(user_id, %{guild_id: guild_id, channel_id: channel_id})

    {:noreply, Map.merge(cache, entry)}
  end

  @impl true
  def handle_call({:get, user_id}, _from, cache) do
    {:reply, Map.get(cache, user_id), cache}
  end
end
