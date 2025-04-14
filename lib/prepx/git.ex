defmodule Prepx.Git do
  @moduledoc """
  Handles interactions with the Git command-line tool.
  """

  @doc """
  Get the root directory of the Git repository.

  ## Returns

  * `{:ok, repo_root}` - The absolute path to the Git repository root
  * `{:error, reason}` - An error message if the directory is not a Git repository
  """
  def get_git_repo_root do
    case System.cmd("git", ["rev-parse", "--show-toplevel"], stderr_to_stdout: true) do
      {root, 0} -> {:ok, String.trim(root)}
      {error, _} -> {:error, "Not a Git repository: #{String.trim(error)}"}
    end
  end

  @doc """
  Get files tracked by Git, respecting .gitignore rules.

  ## Parameters

  * `repo_root` - The absolute path to the Git repository root

  ## Returns

  * `{:ok, file_list}` - A list of tracked files (relative to repo_root)
  * `{:error, reason}` - An error message if Git command failed
  """
  def get_git_tracked_files(repo_root) do
    case System.cmd("git", ["ls-files", "-co", "--exclude-standard"], cd: repo_root) do
      {files, 0} ->
        file_list = files |> String.split("\n", trim: true)
        {:ok, file_list}

      {error, _} ->
        {:error, "Failed to list Git files: #{String.trim(error)}"}
    end
  end
end
