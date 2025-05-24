defmodule ChatApp.Application do
  @moduledoc """
  El módulo de aplicación principal para el servidor de chat.
  Este módulo inicia el supervisor y el servidor de chat.
  """

  use Application

  # Inicia la aplicación y el supervisor
  @impl true
  def start(_type, _args) do
    children = [
      ChatApp.Supervisor
    ]

    opts = [strategy: :one_for_one, name: ChatApp.AppSupervisor]

    Supervisor.start_link(children, opts)
  end

  # Detiene la aplicación
  @impl true
  def stop(_state) do
    :ok
  end
end
