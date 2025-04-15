defmodule Prepx.GitInterface do
  @moduledoc """
  Handles interactions with the Git command-line tool.
  """

  @behaviour Prepx.GitBehaviour

  @doc """
  Check if a path is inside a git repo and not git-ignored.
  Returns true if the path is in a git repo and not ignored, false otherwise.
  """
  def in_git_repo?(path) do
    # Find the repo root (if any)
    case System.cmd("git", ["rev-parse", "--show-toplevel"],
           stderr_to_stdout: true,
           cd: Path.dirname(path)
         ) do
      {root, 0} ->
        repo_root = String.trim(root)
        rel_path = Path.relative_to(path, repo_root)
        # Use git check-ignore; if exit status is 0, it's ignored
        {_, status} = System.cmd("git", ["check-ignore", rel_path], cd: repo_root)
        status != 0

      {_, _} ->
        false
    end
  end
end
