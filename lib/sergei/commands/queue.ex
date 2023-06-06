defmodule Sergei.Commands.Queue do
  # Translate params to list of maps
  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @queue_add_opts [
    opt.(3, "url", "URL of the audio to queue", required: true)
  ]

  @queue_commands [
    opt.(1, "add", "Add a song to the queue", options: @queue_add_opts),
    opt.(1, "clear", "Clear the queue", [])
  ]

  def subcommands() do
    @queue_commands
  end

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
