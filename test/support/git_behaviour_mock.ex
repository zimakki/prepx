defmodule Prepx.GitBehaviourMock do
  @behaviour Prepx.GitBehaviour

  def in_git_repo?(path), do: raise("in_git_repo?/1 not mocked for #{inspect(path)}")
end
