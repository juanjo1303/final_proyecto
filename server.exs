defmodule Server do
  def start do
    Process.register(self(), :server)
    IO.puts("Server iniciado en #{node()}")

    salas = %{}
    loop(salas)
  end

  defp loop(salas) do
    receive do
      {:ingresar, sala, {id_cliente, nodo_cliente}} ->
        IO.puts("#{id_cliente} ingresó a la sala #{sala}")
        clave = {sala, id_cliente}
        actualizar_salas =
        Map.update(salas, clave, [nodo_cliente], fn lista ->
          if nodo_cliente in lista do
            lista
          else
            [nodo_cliente | lista]
          end
        end)

      IO.inspect(actualizar_salas, label: "Estado actual de salas")
      loop(actualizar_salas)

      {:mensaje, sala, mensaje, {enviar_id, enviar_nodo}} ->
        if Map.has_key?(salas, {sala, enviar_id}) do
          IO.puts("#{enviar_id} enviado a #{sala}: #{mensaje}")
          transmitir(salas, sala, mensaje, enviar_nodo)
        else
          IO.puts("Usuario #{enviar_id} intentó enviar mensaje a sala #{sala} sin estar registrado.")
          send({:cliente, enviar_nodo}, {:error, :no_autorizado})
      end
        IO.inspect(salas, label: "Estado actual de salas")
        loop(salas)

      {:salir, sala, {id_cliente, nodo_cliente}} ->
        IO.puts("#{id_cliente} ha salido de la sala #{sala}")
        actualizar_salas = remover_clientes(salas, sala, id_cliente, nodo_cliente)
        IO.inspect(actualizar_salas, label: "Estado actual de salas")
        loop(actualizar_salas)

      {:lista, sala, pid_cliente} ->
        clientes =
          salas
          |> Enum.filter(fn {{sala_temp, _id}, _nodos} -> sala_temp == sala end)
          |> Enum.map(fn {{_sala_temp, id}, _nodos} -> id end)
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
        unless enviar_nodo == nodo_cliente do
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

        cond do
          actualizar_clientes == [] ->
            Map.delete(salas, clave)

          true ->
            Map.put(salas, clave, actualizar_clientes)
        end
    end
  end
end

Server.start()
