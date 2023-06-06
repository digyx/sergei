defmodule Sergei.Commands.Queue do
  @spec handle(integer(), String.t(), [%{name: String.t(), value: String.t()}]) ::
          {:ok, String.t()} | {:err, String.t()}
  def handle(guild_id, "add", opts) do
    [
      %{name: "url", value: url}
    ] = opts

    case Sergei.Player.queue_add(guild_id, url) do
      :ok ->
        {:ok, "Song queued."}

      :not_playing ->
        {:ok, "I'm not playing anything right now."}
    end
  end

  def handle(guild_id, "clear", _opts) do
    case Sergei.Player.queue_clear(guild_id) do
      :ok ->
        {:ok, "Queue cleared."}

      :not_playing ->
        {:ok, "I'm not playing anything right now."}
    end
  end
end
