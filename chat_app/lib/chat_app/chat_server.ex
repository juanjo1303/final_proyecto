defmodule ChatApp.ChatServer do
  @moduledoc """
  Módulo para el servidor de chat.
  Este módulo gestiona la creación de salas, el registro de usuarios,
  la transmisión de mensajes y la gestión de sesiones de usuario.
  """

  # Esta funcion inicia el servidor de chat y lo registra con un nombre global
  def start_link() do
    pid = spawn_link(fn -> init() end)
    {:ok, pid}
  end

  # Esta funcion inicializa el servidor de chat.
  # Registra el PID del proceso con un nombre global para fácil acceso
  def init() do
    Process.register(self(), :server) # Registra el PID con un nombre global para fácil acceso
    IO.puts("Server iniciado en #{node()}")
    # Inicialización del estado del servidor
    salas = %{}
    user_manager = UserManager.cargar_usuarios()
     # Asume que UserManager tiene un struct y constructor apropiado
    clave_cifrado = :crypto.strong_rand_bytes(32) |> Base.encode64()

    # Almacena los procesos de los usuarios activos
    usuarios_activos = %{}  # <- Aquí almacenamos usuarios logueados con sus PID
    # Inicia el bucle recursivo que procesa los mensajes
    loop(salas, user_manager, clave_cifrado, usuarios_activos)
  end

  # Esta funcion es el bucle principal del servidor.
  def loop(salas, user_manager, clave_cifrado, usuarios_activos) do
    receive do
      {:crear_sala, sala, cliente} when is_binary(sala) and is_tuple(cliente) ->
        IO.puts("Creando sala #{sala} para #{inspect(cliente)}")
        nuevas_salas = ChatRoom.crear_sala(salas, sala, cliente)
        loop(nuevas_salas, user_manager, clave_cifrado, usuarios_activos)

      {:crear_sala, sala, cliente} ->
        nuevas_salas = ChatRoom.crear_sala(salas, sala, cliente)
        loop(nuevas_salas, user_manager, clave_cifrado, usuarios_activos)

      {:listar_salas} ->
        IO.puts("Listando salas")
        send({:cliente, node()}, {:salas_disponibles, salas})
        loop(salas, user_manager, clave_cifrado, usuarios_activos)

      {:ingresar, sala, cliente} ->
        nuevas_salas = ChatRoom.ingresar(salas, sala, cliente, user_manager.usuarios, clave_cifrado)
        loop(nuevas_salas, user_manager, clave_cifrado, usuarios_activos)

      {:salir, sala, cliente} ->
        IO.puts("#{inspect(cliente)} ha salido de la #{sala}")
        nuevas_salas = ChatRoom.salir(salas, sala, cliente, clave_cifrado)
        loop(nuevas_salas, user_manager, clave_cifrado, usuarios_activos)

      {:mensaje, sala, mensaje_cifrado, cliente} ->
        if ChatRoom.verificar_estado_sala(salas, elem(cliente, 0)) do
          mensaje = Crypto.descifrar(mensaje_cifrado, clave_cifrado)
          ChatRoom.transmitir(salas, sala, mensaje, cliente, clave_cifrado)

        else
          send({:cliente, elem(cliente, 1)}, {:error, :no_autorizado})
        end

        IO.inspect(salas)
        Process.send_after(self(), {:inactividad, nombre}, 15_000)
        loop(salas, user_manager, clave_cifrado, usuarios_activos)

      {:lista, sala, pid} ->

        clientes =
          salas
          |> Enum.filter(fn {{s, _}, _} -> s == sala end)
          |> Enum.map(fn {{_, id}, _} -> id end)
          |> Enum.uniq()

        send(pid, {:tupla, clientes})
        loop(salas, user_manager, clave_cifrado, usuarios_activos)

      {:historial, sala, pid} ->
        historial = ChatRoom.obtener_historial(sala)
        lineas = String.split(historial, "\n", trim: true)
        lineas_cifradas = Enum.map(lineas, fn linea -> Crypto.cifrar(linea, clave_cifrado) end)
        historial_cifrado = Enum.join(lineas_cifradas, "\n")
        send(pid, {:historial, historial_cifrado})
        loop(salas, user_manager, clave_cifrado, usuarios_activos)

      {:registrar_usuario, nombre, contraseña, cliente_pid} ->
        IO.puts("Intento de registro de #{nombre}")

        case UserManager.registrar_usuario(user_manager, nombre, contraseña) do
          {:ok, nuevo_user_manager} ->
            send(cliente_pid, {:registro_exitoso})
            loop(salas, nuevo_user_manager, clave_cifrado, usuarios_activos)

          {:error, mensaje} ->
            send(cliente_pid, {:error, mensaje})
            loop(salas, user_manager, clave_cifrado, usuarios_activos)
        end

      {:iniciar_sesion, nombre, contraseña, cliente_pid} ->
        IO.puts("Intento de inicio de sesión de #{nombre}")

        case UserManager.iniciar_sesion(user_manager, nombre, contraseña) do
          {:ok, _mensaje} ->
            send(cliente_pid, {:login_exitoso, clave_cifrado})
            # Agregar al mapa de usuarios activos
            nuevos_usuarios_activos = Map.put(usuarios_activos, nombre, cliente_pid)
            # Iniciar temporizador de inactividad
            Process.send_after(self(), {:inactividad, nombre}, 15_000)
            loop(salas, user_manager, clave_cifrado, nuevos_usuarios_activos)

          {:contraseña_incorrecta} ->
            send(cliente_pid, {:error, :contraseña_incorrecta})
            loop(salas, user_manager, clave_cifrado, usuarios_activos)

          {:usuario_no_encontrado} ->
            send(cliente_pid, {:error, :usuario_no_encontrado})
            loop(salas, user_manager, clave_cifrado, usuarios_activos)
        end

      {:inactividad, username} ->
        case Map.get(usuarios_activos, username) do
          nil ->
            IO.puts("Usuario #{username} ya no está activo.")
            loop(salas, user_manager, clave_cifrado, usuarios_activos)

          pid ->
            IO.puts("Usuario #{username} inactivo. Cerrando sesión.")
            send(pid, {:desconexion_por_inactividad})
            Process.exit(pid, :normal)
            nuevos_usuarios_activos = Map.delete(usuarios_activos, username)
            loop(salas, user_manager, clave_cifrado, nuevos_usuarios_activos)
        end
      _ ->
        IO.puts("Comando no reconocido")
        loop(salas, user_manager, clave_cifrado, usuarios_activos)
    end
  end
end
