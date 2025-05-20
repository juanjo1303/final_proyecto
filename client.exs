defmodule Client do
  @node :"servidor@127.0.0.1"

  def start do
    nombre = IO.gets("Ingresa tu nombre: ") |> String.trim()
    sala = IO.gets("A que sala quieres ingresar?: ") |> String.trim()
    IO.puts("#{sala}")

    IO.puts("Conectando al servidor...")
    case Node.connect(@node) do
      true -> IO.puts("Felizmente conectado al server!")
      false -> IO.puts("Error en la conexion!")
    end
    send({:server, @node}, {:ingresar, sala, {nombre, node()}})

    spawn(fn ->
      Process.register(self(), :cliente)
      escuchar_mensajes()
    end)
    enviar_mensaje(sala, nombre)
  end

  defp escuchar_mensajes do
    receive do
      {:mensaje_recibido, sala, mensaje} ->
        IO.puts("[#{sala}] #{mensaje}")
        escuchar_mensajes()
      {:sala_vacia} ->
        IO.puts("No hay personas en la sala")
        escuchar_mensajes()
    end
  end

  defp enviar_mensaje(sala, nombre) do
    mensaje = IO.gets("> ") |> String.trim()
    if String.starts_with?(String.downcase(mensaje),["/join", "/salir", "/history", "/list"]) do
      comando = inicio_string(mensaje)
      case comando do
      "/salir" ->
        send({:server, @node}, {:salir, sala, {nombre, node()}})
        IO.puts("Ha salido de la sala #{sala}")
        enviar_mensaje(sala, nombre)
      "/join" ->
        nueva_sala = mensaje |> final_string()
        send({:server, @node}, {:ingresar, nueva_sala, {nombre, node()}})
        IO.puts("Ha entrado a la sala #{nueva_sala}")
        enviar_mensaje(nueva_sala, nombre)
      "/list" ->
        send({:server, @node}, {:lista, sala, self()})
        receive do
          {:tupla, lista} ->
            IO.puts("En la sala se encuentran: #{inspect(lista)}")
            enviar_mensaje(sala, nombre)
        end
      _ ->
        IO.puts("Comando no reconocido ")
        enviar_mensaje(sala, nombre)
      end
    else
        send({:server, @node}, {:mensaje, sala, "#{nombre}: #{mensaje}", {nombre, node()}})
        enviar_mensaje(sala, nombre)
    end
  end

  def inicio_string(mensaje) do
    mensaje
    |> String.split(" ")
    |> hd()
  end

  def final_string(mensaje) do
    mensaje
    |> String.split(" ")
    |> tl()
    |> Enum.join(" ")

  end
end

Client.start()
