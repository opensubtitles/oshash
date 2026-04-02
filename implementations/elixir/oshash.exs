#!/usr/bin/env elixir
# OpenSubtitles Hash (OSHash) - Elixir implementation.

defmodule OSHash do
  import Bitwise

  @chunk_size 65536

  def compute_hash(filepath) do
    {:ok, stat} = File.stat(filepath)
    fsize = stat.size

    if fsize < @chunk_size * 2 do
      raise "File too small: #{fsize} bytes"
    end

    {:ok, file} = :file.open(filepath, [:binary, :read])

    # Hash first 64KB
    {:ok, head_data} = :file.read(file, @chunk_size)
    head_hash = sum_chunk(head_data)

    # Hash last 64KB
    :file.position(file, {:bof, max(0, fsize - @chunk_size)})
    {:ok, tail_data} = :file.read(file, @chunk_size)
    tail_hash = sum_chunk(tail_data)

    :file.close(file)

    hash = band(fsize + head_hash + tail_hash, 0xFFFFFFFFFFFFFFFF)
    hash |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(16, "0")
  end

  defp sum_chunk(data) do
    sum_chunk(data, 0)
  end

  defp sum_chunk(<<val::unsigned-little-integer-size(64), rest::binary>>, acc) do
    sum_chunk(rest, band(acc + val, 0xFFFFFFFFFFFFFFFF))
  end

  defp sum_chunk(<<>>, acc), do: acc
end

case System.argv() do
  [filepath | _] ->
    IO.puts(OSHash.compute_hash(filepath))
  _ ->
    IO.puts(:stderr, "Usage: elixir oshash.exs <file>")
    System.halt(1)
end
