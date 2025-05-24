defmodule Crypto do
  # Deriva una clave de 32 bytes usando SHA-256
  defp derive_key(password) do
    :crypto.hash(:sha256, password)
  end

  # Padding PKCS#7
  defp pad(data) do
    to_add = 16 - rem(byte_size(data), 16)
    data <> :binary.copy(<<to_add>>, to_add)
  end

  defp unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  # Cifrar mensaje
  def cifrar(mensaje, clave) do
    iv = :crypto.strong_rand_bytes(16)
    clave_bin = derive_key(clave)
    padded = pad(mensaje)
    cifrado = :crypto.crypto_one_time(:aes_256_cbc, clave_bin, iv, padded, true)
    iv <> cifrado |> Base.encode64()
  end

  # Descifrar mensaje
  def descifrar(mensaje_cifrado_base64, clave) do
    bin = Base.decode64!(mensaje_cifrado_base64)
    <<iv::binary-16, cifrado::binary>> = bin
    clave_bin = derive_key(clave)
    descifrado = :crypto.crypto_one_time(:aes_256_cbc, clave_bin, iv, cifrado, false)
    unpad(descifrado)
  end
end

# Para generar una clave aleatoria, ejecuta:
# Cookie.main()

# Ejemplo de uso:
# clave = "mi_clave_secreta"
# cifrado = Crypto.cifrar("hola mundo", clave)
# IO.puts("Cifrado: #{cifrado}")
# descifrado = Crypto.descifrar(cifrado, clave)
# IO.puts("Descifrado: #{descifrado}")
