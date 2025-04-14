defmodule Prepx.FileSystemReal do
  @moduledoc """
  The real implementation of the FileSystemBehaviour using Elixir's File module.
  """

  @behaviour Prepx.FileSystemBehaviour

  @impl Prepx.FileSystemBehaviour
  def cwd, do: File.cwd()

  @impl Prepx.FileSystemBehaviour
  def read!(path), do: File.read!(path)

  @impl Prepx.FileSystemBehaviour
  def write!(path, content), do: File.write!(path, content)

  @impl Prepx.FileSystemBehaviour
  def regular?(path), do: File.regular?(path)
end
