defmodule Prepx do
  @moduledoc """
  Prepx is a CLI tool that consolidates a Git repository's codebase into a single text file,
  primarily for providing context to Large Language Models (LLMs).

  The tool respects .gitignore rules and works from any directory within a Git repository.

  ## Features

  * Generates a directory structure summary
  * Includes file contents with clear markers
  * Skips binary files
  * Respects .gitignore exclusions
  * Works from any subdirectory in a Git repository
  """

  @doc """
  Returns the current version of the application.
  """
  def version do
    Application.spec(:prepx, :vsn)
  end
end
