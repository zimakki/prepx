defmodule Prepx.CLI do
  @moduledoc """
  Command-line interface for Prepx.
  """

  def main(args) do
    {_opts, _args, _invalid} = OptionParser.parse(args)

    case Prepx.Core.process() do
      {:ok, output_path} ->
        IO.puts("Successfully created LLM context file at: #{output_path}")

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        System.halt(1)
    end
  end
end
