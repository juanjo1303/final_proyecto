# Chat Distribuido en Elixir

Este proyecto implementa un sistema de chat distribuido con autenticación, salas y cifrado de mensajes usando Elixir.

## Características

- Múltiples salas de chat
- Autenticación de usuarios (login con token/cookie)
- Persistencia en memoria o base de datos
- Comunicación cliente-servidor
- Cifrado de mensajes

## Requisitos

- Elixir 1.18
- Erlang/OTP 28

## Estructura

- Estructura simple haciendo uso de las funciones basicas de Elixir sin hacer uso de GenServer

##  Como se usa
Este comando se ejecuta en la carpeta de cliente
elixir --name cliente@192.168.1.4 --cookie mi_cookie chat_client.ex

Este comando se ejecuta en la carpeta de chat_app
cmd /c "iex --name servidor@192.168.1.4 --cookie mi_cookie -S mix"

## Autores

-Juan Jose Carvajal Gomez
-Nicolas Valencia Muñoz

## Notas Adicionales

A la hora de crear los diferentes usuarios hay que cambiar la parte a la izquiera del arroba
comunmente se suele usar de esta forma:

-elixir --name cliente1@192.168.1.4 --cookie mi_cookie chat_client.ex
-elixir --name cliente2@192.168.1.4 --cookie mi_cookie chat_client.ex
-elixir --name cliente3@192.168.1.4 --cookie mi_cookie chat_client.ex
-elixir --name cliente4@192.168.1.4 --cookie mi_cookie chat_client.ex


