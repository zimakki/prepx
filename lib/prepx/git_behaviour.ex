defmodule Prepx.GitBehaviour do
  @moduledoc """
  Behaviour for checking if a path is inside a git repo and not git-ignored.
  """

  @callback in_git_repo?(String.t()) :: boolean
end
