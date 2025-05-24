defmodule ChatApp.Supervisor do
  @moduledoc """
  Supervisor para el servidor de chat.
  Inicia el proceso del servidor de chat y lo supervisa.
  """

  use Supervisor


  #Inicia el supervisor del servidor de chat.
  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  #Inicializa el supervisor con el proceso del servidor de chat.
  @impl true
  def init(:ok) do
  children = [
    %{
      id: ChatApp.ChatServer,
      start: {ChatApp.ChatServer, :start_link, []},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
