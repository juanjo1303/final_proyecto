Code.require_file("cookies.ex")

defmodule Client do
  @moduledoc """
  Módulo para el cliente del sistema de chat.
  Este módulo gestiona la conexión al servidor, el registro de usuarios,
  el inicio de sesión y la interacción con el usuario.
  """

  # Inicia el cliente y se conecta al servidor
  @node :"servidor@192.168.1.4"

  # Conexión al servidor
  def start do
    IO.puts("Conectando al servidor...")
    case Node.connect(@node) do
      true -> IO.puts("Felizmente conectado al server!")
      false -> IO.puts("Error en la conexion!")
    end
    IO.puts("""
    ¿Qué deseas hacer?
    1. Registrarme
    2. Iniciar sesión
    """)
    opcion = IO.gets("Selecciona una opción (1/2): ") |> String.trim()
    case opcion do
      "1" ->
        register_loop()
      "2" ->
        login_loop()
      _ ->
        IO.puts("Opción no válida. Intenta de nuevo.")
        start()
    end

  end

  # Bucle de registro de usuario
  defp register_loop() do
    username = vacio_o_nil?("Ingrese el nombre de usuario que desea usar: ")
    case registrar_usuario(username) do
      true ->
        IO.puts("Usuario registrado exitosamente.")
        login_loop()
      false ->
        IO.puts("Error al registrar usuario. Intenta de nuevo.")
        register_loop()
    end
  end
  # Bucle de inicio de sesión
  defp login_loop() do
    username = vacio_o_nil?("Ingrese su usuario: ")
    case iniciar_sesion(username) do
      true ->
        sala = "lobby"
        send({:server, @node}, {:crear_sala, sala, {username, node()}})
        send({:server, @node}, {:ingresar, sala, {username, node()}})
          IO.puts("""
          Te hemos conectado a la sala #{sala}""")
          Lista de comandos:
          /join <sala> - Unirse a una sala
          /leave - Salir de la sala actual
          /history - Ver el historial de mensajes
          /list - Ver la lista de usuarios en la sala
          /create <sala> - Crear una nueva sala
          """)
        spawn(fn ->
          Process.register(self(), :cliente)
          escuchar_mensajes()
        end)
        enviar_mensaje(sala, username)
      false ->
        login_loop()
      :usuario_no_encontrado ->
        register_loop()
      :contraseña_incorrecta ->
        login_loop()
      _ ->
        login_loop()
    end
  end

  # Escucha mensajes del servidor
  # y los muestra en la consola
  def escuchar_mensajes do
    receive do
      {:mensaje_recibido, sala, mensaje_cifrado, clave_cifrado} ->
        if is_binary(mensaje_cifrado) and byte_size(mensaje_cifrado) > 0 and is_binary(clave_cifrado) and byte_size(clave_cifrado) > 0 do
          mensaje = Crypto.descifrar(mensaje_cifrado, clave_cifrado)
          IO.puts("[#{sala}] #{mensaje}")
        else
          IO.puts("[#{sala}] (No se pudo descifrar el mensaje)")
        end
        escuchar_mensajes()
      {:sala_vacia} ->
        IO.puts("No hay personas en la sala")
        escuchar_mensajes()
    end
  end

  # Envía mensajes al servidor
  # y maneja los comandos especiales
  def enviar_mensaje(sala, nombre) do
    mensaje = IO.gets("> ") |> String.trim()

    if String.starts_with?(String.downcase(mensaje), ["/join", "/leave", "/history", "/list", "/create", "/comandos"]) do
      comando = inicio_string(mensaje)

      case comando do
        "/leave" ->
          send({:server, @node}, {:salir, sala, {nombre, node()}})
          IO.puts("Has vuelto al lobby")
          send({:server, @node}, {:ingresar, "lobby", {nombre, node()}})
          enviar_mensaje(sala, nombre)

        "/join" ->
          nueva_sala = mensaje |> final_string()
          send({:server, @node}, {:ingresar, nueva_sala, {nombre, node()}})
          IO.puts("Has entrado a la sala #{nueva_sala}")
          enviar_mensaje(nueva_sala, nombre)

        "/list" ->
          send({:server, @node}, {:lista, sala, self()})
          receive do
            {:tupla, lista} ->
              IO.puts("En la sala se encuentran: #{inspect(lista)}")
              enviar_mensaje(sala, nombre)

          end
        "/history" ->
          send({:server, @node}, {:historial, sala, self()})
          receive do
            {:historial, contenido} ->
              clave_cifrado = Process.get(:clave_cifrado)
              lineas = String.split(contenido, "\n", trim: true)
              descifradas = Enum.map(lineas, fn linea ->
                  Crypto.descifrar(linea, clave_cifrado)
              end)
              IO.puts("Historial de la sala:\n#{Enum.join(descifradas, "\n")}")
              enviar_mensaje(sala, nombre)
          end

        "/create" ->
          nueva_sala = mensaje |> final_string()
          send({:server, @node}, {:crear_sala, nueva_sala, {nombre, node()}})
          IO.puts("Sala #{nueva_sala} creada.")
          enviar_mensaje(nueva_sala, nombre)

        "/comandos" ->
          IO.puts("""
          Lista de comandos:
          /join <sala> - Unirse a una sala
          /leave - Salir de la sala actual
          /history - Ver el historial de mensajes
          /list - Ver la lista de usuarios en la sala
          /create <sala> - Crear una nueva sala
          """)
          enviar_mensaje(sala, nombre)

        _ ->
          IO.puts("Comando no reconocido ")
          enviar_mensaje(sala, nombre)
      end


    else
      clave_cifrado = Process.get(:clave_cifrado)
      mensaje_cifrado = Crypto.cifrar(mensaje, clave_cifrado)
      send({:server, @node}, {:mensaje, sala, mensaje_cifrado, {nombre, node()}})
      enviar_mensaje(sala, nombre)
    end
  end

  # Elimina el ultimo elemento de la cadena
  def inicio_string(mensaje) do
    mensaje
    |> String.split(" ")
    |> hd()
  end

  # Elimina el primer elemento de la cadena
  def final_string(mensaje) do
    mensaje
    |> String.split(" ")
    |> tl()
    |> Enum.join(" ")
  end

  # Registra un nuevo usuario
  defp registrar_usuario(username) do
    password = IO.gets("Ingrese la contraseña para su cuenta: ") |> String.trim()
    send({:server, @node}, {:registrar_usuario, username, password, self()})
    receive do
      {:registro_exitoso} ->
        true
      {:error, mensaje} ->
        IO.puts("Error al registrar usuario: #{mensaje}")
        registrar_usuario(username)
    end
  end

  # Inicia sesión con un usuario existente
  defp iniciar_sesion(username) do
    password = IO.gets("Ingrese su contraseña: ") |> String.trim()
    send({:server, @node}, {:iniciar_sesion, username, password, self()})
    receive do
      {:login_exitoso, clave_cifrado} ->
        IO.puts("Inicio de sesión exitoso.")
        Process.put(:clave_cifrado, clave_cifrado)  # Almacenar la clave
        true
      {:error, mensaje} ->
        IO.puts("Error al iniciar sesión: #{mensaje}")
        false
      {:contraseña_incorrecta} ->
        IO.puts("Contraseña incorrecta.")
        :contraseña_incorrecta
      {:usuario_no_encontrado} ->
        IO.puts("Usuario no encontrado.")
        :usuario_no_encontrado
    end
  end

  # Verifica si el mensaje está vacío o es nil
  def vacio_o_nil?(mensaje) do
    valor = IO.gets("#{mensaje}") |> String.trim()
    case valor do
      nil ->
        "caracteres invalidos"
        vacio_o_nil?(mensaje)
      "" ->
        "caracteres invalidos"
        vacio_o_nil?(mensaje)
      " " ->
        "caracteres invalidos"
        vacio_o_nil?(mensaje)
      _ -> valor
    end
  end
end

Client.start()
