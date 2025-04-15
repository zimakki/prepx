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

  * `_args` - List of command-line arguments (currently not used)
  """
  def main(_args) do
    IO.puts("Processing repository...")

    case Prepx.Core.process() do
      {:ok, output_path} ->
        IO.puts("Successfully created LLM context file: #{output_path}")
        System.halt(0)
    end
  end
end
