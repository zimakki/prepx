defmodule Prepx.GitBehaviourMock do
  @moduledoc """
  Mox mock for Prepx.GitBehaviour.
  """
  @behaviour Prepx.GitBehaviour

  def in_git_repo?(path), do: raise("in_git_repo?/1 not mocked for #{inspect(path)}")
end
