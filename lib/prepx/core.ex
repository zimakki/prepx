defmodule Prepx.Core do
  @moduledoc """
  Core functionality for the Prepx tool.

  This module handles the processing of Git repositories to generate
  a consolidated text file for LLM context.
  """

  @output_filename "llm_context.txt"

  @doc """
  Process the current working directory and create the LLM context file.

  ## Returns

  * `{:ok, output_path}` - The path to the created context file
  * `{:error, reason}` - An error message if processing failed
  """
  def process do
    with {:ok, repo_root} <- get_git_repo_root(),
         cwd = File.cwd!(),
         {:ok, tracked_files} <- get_git_tracked_files(repo_root),
         relative_files = filter_files_by_cwd(tracked_files, repo_root, cwd),
         {:ok, file_tree} <- build_file_tree(relative_files),
         {:ok, output_path} <- generate_output_file(file_tree, relative_files, cwd, repo_root) do
      {:ok, output_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

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
        {:error, "Failed to get Git tracked files: #{String.trim(error)}"}
    end
  end

  @doc """
  Filter files to only those within the current working directory.

  ## Parameters

  * `files` - List of files relative to the repository root
  * `repo_root` - The absolute path to the Git repository root
  * `cwd` - The current working directory

  ## Returns

  A list of files filtered to only those in the current working directory,
  with paths adjusted to be relative to the current directory.
  """
  def filter_files_by_cwd(files, repo_root, cwd) do
    rel_cwd = Path.relative_to(cwd, repo_root)
    rel_cwd = if rel_cwd == "", do: ".", else: rel_cwd

    files
    |> Enum.filter(fn file ->
      String.starts_with?(file, rel_cwd) or rel_cwd == "."
    end)
    |> Enum.map(fn file ->
      Path.relative_to(file, if(rel_cwd == ".", do: "", else: rel_cwd))
    end)
  end

  @doc """
  Build a tree structure representing the directory hierarchy.

  ## Parameters

  * `files` - List of files to organize into a tree structure

  ## Returns

  * `{:ok, tree}` - A map representing the directory tree
  """
  def build_file_tree(files) do
    tree =
      Enum.reduce(files, %{}, fn file, acc ->
        path_parts = Path.split(file) |> Enum.filter(&(&1 != "."))

        put_in_nested(acc, path_parts, file)
      end)

    {:ok, tree}
  end

  defp put_in_nested(map, [key], file) do
    Map.update(map, key, %{__file__: file}, fn existing ->
      Map.put(existing, :__file__, file)
    end)
  end

  defp put_in_nested(map, [key | rest], file) do
    Map.update(map, key, put_in_nested(%{}, rest, file), fn existing ->
      put_in_nested(existing, rest, file)
    end)
  end

  @doc """
  Generate the output file with directory summary and file contents.

  ## Parameters

  * `file_tree` - The directory tree structure
  * `files` - List of files to include in the output
  * `cwd` - The current working directory
  * `repo_root` - The absolute path to the Git repository root

  ## Returns

  * `{:ok, output_path}` - The path to the created context file
  * `{:error, reason}` - An error message if file creation failed
  """
  def generate_output_file(file_tree, files, cwd, repo_root) do
    output_path = Path.join(cwd, @output_filename)

    contents = [
      generate_dir_summary(file_tree),
      "\n\n",
      generate_file_contents(files, cwd, repo_root)
    ]

    case File.write(output_path, IO.iodata_to_binary(contents)) do
      :ok -> {:ok, output_path}
      {:error, reason} -> {:error, "Failed to write output file: #{reason}"}
    end
  end

  @doc """
  Generate a text-based tree summary of the directory structure.

  ## Parameters

  * `file_tree` - The directory tree structure

  ## Returns

  A list of strings representing the directory structure as a tree.
  """
  def generate_dir_summary(file_tree) do
    ["# Directory Structure\n\n"] ++ format_tree(file_tree, "", true)
  end

  defp format_tree(tree, prefix, is_last) do
    keys = Map.keys(tree) |> Enum.reject(&(&1 == :__file__)) |> Enum.sort()

    Enum.flat_map(Enum.with_index(keys), fn {key, index} ->
      is_last_key = index == length(keys) - 1
      current_prefix = if is_last, do: "└── ", else: "├── "
      next_prefix = if is_last, do: "    ", else: "│   "

      subtree = Map.get(tree, key)

      if is_map(subtree) and map_size(subtree) > 0 and not Map.has_key?(subtree, :__file__) do
        [prefix <> current_prefix <> key <> "\n"] ++
          format_tree(subtree, prefix <> next_prefix, is_last_key)
      else
        [prefix <> current_prefix <> key <> "\n"]
      end
    end)
  end

  @doc """
  Generate the content section with file contents and markers.

  ## Parameters

  * `files` - List of files to include in the output
  * `cwd` - The current working directory
  * `repo_root` - The absolute path to the Git repository root

  ## Returns

  A list of strings containing the file contents with appropriate markers.
  """
  def generate_file_contents(files, cwd, repo_root) do
    Enum.flat_map(files, fn file ->
      # Ensure we have the correct absolute path to the file
      # For files in current directory when running from a subdirectory
      absolute_path =
        if Path.dirname(file) == "." do
          Path.join(cwd, file)
        else
          Path.join(repo_root, file)
        end

      cond do
        not File.exists?(absolute_path) ->
          ["--- ERROR READING FILE: #{file} (file not found) ---\n\n"]

        binary_file?(absolute_path) ->
          ["--- BINARY FILE (SKIPPED): #{file} ---\n\n"]

        true ->
          read_text_file(absolute_path, file)
      end
    end)
  end

  defp read_text_file(absolute_path, file) do
    case File.read(absolute_path) do
      {:ok, content} ->
        [
          "--- START FILE: #{file} ---\n",
          content,
          "\n--- END FILE: #{file} ---\n\n"
        ]

      {:error, reason} ->
        ["--- ERROR READING FILE: #{file} (#{reason}) ---\n\n"]
    end
  end

  @doc false
  defp binary_file?(path) do
    if File.regular?(path) do
      case File.read(path) do
        {:ok, content} ->
          String.contains?(content, <<0>>)

        {:error, _} ->
          # If we can't read it, treat as binary to be safe
          true
      end
    else
      true
    end
  end
end
