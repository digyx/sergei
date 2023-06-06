defmodule Sergei.Commands.Queue do
  require Logger

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

      {:error, err} ->
        Logger.error("Failed to queue media: #{err}")
        {:error, "This is embarassing..."}
    end
  end
end
