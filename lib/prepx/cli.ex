defmodule Prepx.CLI do
  @moduledoc """
  Command-line interface for Prepx.

  This module provides the entry point for the escript binary,
  processing command-line arguments and delegating to the Core module.
  """

  @doc """
  The main entry point for the escript.

  Processes command-line arguments and executes the core functionality.

  ## Parameters

  * `args` - List of command-line arguments (currently not used)
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
