defmodule Prepx.FileSystemBehaviour do
  @moduledoc """
  Defines the behaviour for interacting with the file system.
  This allows for mocking file operations during testing.
  """

  @callback cwd() :: {:ok, String.t()} | {:error, atom()}
  @callback read!(path :: String.t()) :: String.t() | no_return()
  @callback write!(path :: String.t(), content :: String.t()) :: :ok | no_return()
  @callback regular?(path :: String.t()) :: boolean()
end
