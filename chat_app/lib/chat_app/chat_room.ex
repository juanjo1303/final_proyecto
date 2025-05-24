defmodule ChatRoom do
  @moduledoc """
  Módulo para gestionar salas de chat.
  Proporciona funciones para crear salas, ingresar y salir de ellas,
  transmitir mensajes y guardar el historial de mensajes.
  """
  # Este módulo gestiona la creación de salas
  def crear_sala(salas, sala, {id_cliente, nodo_cliente}) do
    clave = {sala, id_cliente}
    if Map.has_key?(salas, clave) do
      IO.puts("La sala #{sala} ya existe.")
      log_admin("La sala #{sala} ya existe.")
      salas

    else
      IO.puts("Creando sala #{sala} por #{id_cliente}")
      log_admin("Creando sala #{sala} por #{id_cliente}")
      Map.put(salas, clave, [nodo_cliente])
    end
  end

  # Esta función verifica si el usuario está logueado y si la sala existe
  def ingresar(salas, sala, {id_cliente, nodo_cliente}, logged_in_users, clave_cifrado) do
    if UserManager.usuario_logueado?(logged_in_users, id_cliente) do
      if Enum.any?(salas, fn {{nombre_sala, _}, _clientes} -> nombre_sala == sala end) do
        # El usuario está logueado y la sala existe
        id = id_cliente

        salas =
          if verificar_estado_sala(salas, id_cliente) do
            sala_anterior = encontrar_sala(salas, id_cliente, sala)
            IO.inspect("#{id} ha salido de la sala #{sala_anterior}")
            log_admin("#{id} ha salido de la sala #{sala_anterior}")
            remover_clientes(salas, sala_anterior, id_cliente, nodo_cliente)
          else
            salas
          end

        IO.puts("#{id} ingresó a la sala #{sala}")
        log_admin("#{id} ingresó a la sala #{sala}")
        clave = {sala, id_cliente}
          # Actualiza la sala con el nuevo cliente
        actualizar_salas =
          Map.update(salas, clave, [nodo_cliente], fn lista ->
            if nodo_cliente in lista, do: lista, else: [nodo_cliente | lista]
          end)

        transmitir(salas, sala, "#{id_cliente} ha ingresado a la sala", {id_cliente, nodo_cliente}, clave_cifrado)
        actualizar_salas
      # El usuario está logueado pero la sala no existe
      # En este caso, se le informa al usuario que la sala no existe
      else
        IO.puts("No se pudo ingresar. La sala '#{sala}' no está creada.")
        transmitir(salas, sala, "No se pudo ingresar. La sala no existe.", {id_cliente, nodo_cliente}, clave_cifrado)
        salas
      end
    # El usuario no está logueado
    # En este caso, se le informa al usuario que debe iniciar sesión
    else
      IO.puts("Acceso denegado. El usuario debe iniciar sesión primero.")
      transmitir(salas, sala, "Acceso denegado a la sala", {id_cliente, nodo_cliente}, clave_cifrado)
      salas
    end
  end
  # Esta función se encarga de eliminar al cliente de la sala
  # y de transmitir un mensaje a los demás clientes de la sala
  def salir(salas, sala, {id_cliente, nodo_cliente}, clave_cifrado) do
    salas_actualizadas = remover_clientes(salas, sala, id_cliente, nodo_cliente)
    transmitir(salas_actualizadas, sala, "#{id_cliente} ha salido de la sala", {id_cliente, nodo_cliente}, clave_cifrado)
    salas_actualizadas
  end

  # Esta función se encarga de transmitir el mensaje a todos los clientes de la sala
  # excepto al que lo envió
  def transmitir(salas, sala, mensaje, {enviar_id, enviar_nodo}, clave_cifrado) do
    log_admin("[#{sala}] #{enviar_id}: #{mensaje}")
    clientes_nodos =
      salas
      |> Enum.filter(fn {{sala_temp, _}, _} -> sala_temp == sala end)
      |> Enum.flat_map(fn {_, nodos} -> nodos end)
      |> Enum.uniq()

    if clientes_nodos == [] do
      IO.puts("No hay clientes en la sala #{sala}")
      log_admin("No hay clientes en la sala #{sala}")
      send({:cliente, enviar_nodo}, {:sala_vacia})
    else
      Enum.each(clientes_nodos, fn nodo ->
        unless nodo == enviar_nodo do
          mensaje_cifrado = Crypto.cifrar(mensaje, clave_cifrado)
          send({:cliente, nodo}, {:mensaje_recibido, sala, mensaje_cifrado, clave_cifrado})
        end
      end)
    end

    guardar_mensaje(sala, enviar_id, mensaje)
  end

  # Esta función se encarga de eliminar al cliente de la sala
  # y de eliminar la sala si no hay más clientes en ella
  def remover_clientes(salas, sala, id_cliente, nodo_cliente) do
    clave = {sala, id_cliente}
    case Map.get(salas, clave, []) do
      [] -> salas
      clientes ->
        actualizados = List.delete(clientes, nodo_cliente)
        if actualizados == [], do: Map.delete(salas, clave), else: Map.put(salas, clave, actualizados)
    end
  end

  # Esta función se encarga de encontrar la sala en la que está el cliente
  # y de devolver el nombre de la sala
  def encontrar_sala(salas, id, sala_actual) do
    salas
    |> Map.keys()
    |> Enum.find_value(fn
      {otra_sala, id_usuario} when id_usuario == id and otra_sala != sala_actual -> otra_sala
      _ -> nil
    end)
  end

  # Esta función se encarga de verificar si el cliente está en la sala
  # y de devolver true o false
  def verificar_estado_sala(salas, id) do
    Enum.any?(salas, fn {{_, id_actual}, _} -> id_actual == id end)
  end

  # Guarda el mensaje
  def guardar_mensaje(sala, id, mensaje) do
    File.mkdir_p!("data")
    ruta = "data/#{sala}.txt"
    entrada = "[#{id}] #{mensaje}\n"
    File.write(ruta, entrada, [:append])
  end

  # Pide el historial
  def obtener_historial(sala) do
    ruta = "data/#{sala}.txt"
    case File.read(ruta) do
      {:ok, contenido} -> contenido
      _ -> "📭 No hay historial disponible."
    end
  end

  # Guarda los admin logs
  def log_admin(mensaje) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    entrada = "[#{timestamp}] #{mensaje}"
    IO.puts(entrada)
    File.mkdir_p!("logs")
    File.write!("logs/admin_log.txt", entrada <> "\n", [:append])
  end

end
