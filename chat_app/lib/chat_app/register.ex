defmodule UserManager do
  @usuarios_file "data/usuarios.db"
  defstruct usuarios: %{}
  @moduledoc """
  Módulo para gestionar usuarios en el sistema de chat.
  Proporciona funciones para registrar usuarios, iniciar sesión y verificar si un usuario está registrado.
  """

  # Cargar usuarios desde archivo
  def cargar_usuarios() do
    File.mkdir_p!("data")
    case File.read(@usuarios_file) do
      {:ok, bin} -> %UserManager{usuarios: :erlang.binary_to_term(bin)}
      _ -> %UserManager{usuarios: %{}}
    end
  end

  # Guardar usuarios en archivo
  def guardar_usuarios(%UserManager{usuarios: usuarios}) do
    bin = :erlang.term_to_binary(usuarios)
    File.write!(@usuarios_file, bin)
  end

  # Registrar usuario y guardar
  def registrar_usuario(%UserManager{usuarios: usuarios} = _user_manager, username, password) do
    if Map.has_key?(usuarios, username) do
      {:error, :usuario_existente}
    else
      nuevos_usuarios = Map.put(usuarios, username, password)
      nuevo_user_manager = %UserManager{usuarios: nuevos_usuarios}
      guardar_usuarios(nuevo_user_manager)
      {:ok, nuevo_user_manager}
    end
  end

  # Iniciar sesión
  def iniciar_sesion(%UserManager{usuarios: usuarios}, username, password) do
    case Map.fetch(usuarios, username) do
      :error ->
        {:usuario_no_encontrado}

      {:ok, stored_password} ->
        if stored_password == password do
          {:ok, "Login exitoso."}
        else
          {:contraseña_incorrecta}
        end
    end
  end

  # Verificar si usuario está registrado
  def usuario_logueado?(%UserManager{usuarios: usuarios}, username) do
    Map.has_key?(usuarios, username)
  end
  def usuario_logueado?(usuarios, username) when is_map(usuarios) do
    Map.has_key?(usuarios, username)
  end
end
