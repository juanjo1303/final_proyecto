  defmodule Server do
    #start inicia el proceso de servidor
    def start do
      Process.register(self(), :server) #registra el server bajo un proceso (PID)
      IO.puts("Server iniciado en #{node()}")

      salas = %{} #crea la lista de salas
      loop(salas)
    end

    defp loop(salas) do #esto es lo que recibe y le da la logica a funcionalidades como join leave history etc etc
      receive do
        {:ingresar, sala, {id_cliente, nodo_cliente}} ->
    salas =
      if verificar_estado_sala(salas, id_cliente) do #verifica que la sala ya este creada o no
        sala_anterior = encontrar_sala(salas, id_cliente, sala) #retorna la sala que esta saliendo el usuario para entrar a otra
        IO.puts("#{id_cliente} ha salido de la sala #{sala_anterior}")
        remover_clientes(salas, sala_anterior, id_cliente, nodo_cliente) #quita las otras salas para que solo quede 1
      else
        salas
      end

    IO.puts("#{id_cliente} ingresó a la sala #{sala}")
    clave = {sala, id_cliente}
    actualizar_salas =
      Map.update(salas, clave, [nodo_cliente], fn lista -> #actualiza la lista de salas con una nueva sala
        if nodo_cliente in lista do
          lista
        else
          [nodo_cliente | lista]
        end
      end)

  IO.inspect(actualizar_salas, label: "Estado actual de salas")
  loop(actualizar_salas)

        {:mensaje, sala, mensaje, {enviar_id, enviar_nodo}} ->
          if verificar_estado_sala(salas, enviar_id) == true do #confirma que haya una sala creada con el mismo nombre
            IO.puts("#{enviar_id} enviado a #{sala}: #{mensaje}")
            transmitir(salas, sala, mensaje, enviar_nodo)
          else
            IO.puts("Usuario #{enviar_id} intentó enviar mensaje a sala #{sala} sin estar registrado.") #envia mensaje si la persona no se
            send({:cliente, enviar_nodo}, {:error, :no_autorizado})                                     #encuentra en ninguna sala
        end
          IO.inspect(salas, label: "Estado actual de salas")
          loop(salas)

        {:salir, sala, {id_cliente, nodo_cliente}} ->
          IO.puts("#{id_cliente} ha salido de la sala #{sala}")
          actualizar_salas = remover_clientes(salas, sala, id_cliente, nodo_cliente) #quita clientes de la lista
          IO.inspect(actualizar_salas, label: "Estado actual de salas")
          loop(actualizar_salas)

        {:lista, sala, pid_cliente} ->
          clientes =
            salas
            |> Enum.filter(fn {{sala_temp, _id}, _nodos} -> sala_temp == sala end) #logica que elimina todos los caracteres extra
            |> Enum.map(fn {{_sala_temp, id}, _nodos} -> id end)                   #y solo deja los ids(nombres) de los usuarios
            |> Enum.uniq()

          send(pid_cliente, {:tupla, clientes})
          IO.inspect(salas, label: "Estado actual de salas")
          loop(salas)
        end
      end

    defp transmitir(salas, sala, mensaje, enviar_nodo) do
      clientes_nodos =
        salas
        |> Enum.filter(fn {{sala_temp, _id}, _nodos} -> sala_temp == sala end)
        |> Enum.flat_map(fn {_, nodos} -> nodos end)
        |> Enum.uniq()

        if clientes_nodos == [] do
          IO.puts("No hay clientes en la sala #{sala}")
          send({:cliente, enviar_nodo}, {:sala_vacia})
        else
          IO.puts("Transmitiendo a nodos en sala #{sala}: #{inspect(clientes_nodos)}")
          Enum.each(clientes_nodos, fn nodo_cliente ->
          unless enviar_nodo == nodo_cliente do #logica que le envia los mensajes de un usuario a todos los demas de la sala
            IO.puts("Enviando a #{nodo_cliente}: #{mensaje}")
            send({:cliente, nodo_cliente}, {:mensaje_recibido, sala, mensaje})
          end
        end)
      end
      IO.inspect(salas, label: "Estado actual de salas")
    end

    defp remover_clientes(salas, sala, id_cliente, nodo_cliente) do
      clave = {sala, id_cliente}
      case Map.get(salas, clave, []) do
        [] ->
          salas

        clientes ->
          actualizar_clientes = List.delete(clientes, nodo_cliente)
          if actualizar_clientes == [] do #elimina un cliente de una sala
            Map.delete(salas, clave)
          else
            Map.put(salas, clave, actualizar_clientes)
          end
      end
    end

  def encontrar_sala(salas, id, sala_actual) do
    salas
    |> Map.keys()
    |> Enum.find_value(fn
      {otra_sala, id_usuario} when id_usuario == id and otra_sala != sala_actual -> otra_sala #encuentra las otras salas del usuario
      _ -> nil
    end)
  end

  def verificar_estado_sala(salas, id) do
      estado =
      salas
      |> Map.keys()
      |> Enum.any?(fn
        {_sala, id_actual} when id_actual == id -> true #mira si hay mas personas con el mismo id en otras salas
        _ -> false
      end)
      estado
    end
  end

  Server.start()
