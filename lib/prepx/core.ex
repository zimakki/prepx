defmodule Prepx.Core do
  @moduledoc """
  Core functionality for the Prepx tool.

  This module handles the processing of Git repositories to generate
  a consolidated text file for LLM context.
  """

  @output_filename "llm_context.txt"

  @doc """
  Process the current working directory and create the LLM context file.

  Requires modules implementing FileSystemBehaviour and GitBehaviour.

  ## Returns

  * `{:ok, output_path}` - The path to the created context file
  * `{:error, reason}` - An error message if processing failed
  """
  def process(git_module \\ Prepx.GitInterface) when is_atom(git_module) do
    cwd = File.cwd!()
    all_files = list_all_files(cwd)
    # Pair each file with its absolute and relative path from cwd
    tracked_files =
      all_files
      |> Enum.filter(&git_module.in_git_repo?/1)
      |> Enum.map(fn abs_path ->
        rel_path = Path.relative_to(abs_path, cwd)
        {abs_path, rel_path}
      end)

    tree_map = build_file_tree(Enum.map(tracked_files, fn {_, rel_path} -> rel_path end))
    tree_map = case tree_map do
      {:ok, map} -> map
      map when is_map(map) -> map
      _ -> %{}
    end

    output =
      ["Directory Tree:", "```", format_tree(tree_map), "```", "", "File Contents:"] ++
        Enum.flat_map(tracked_files, fn {abs_path, rel_path} ->
          if binary_file?(abs_path) do
            ["--- File: #{rel_path} (Binary file ignored) ---"]
          else
            case File.read(abs_path) do
              {:ok, content} ->
                ["--- File: #{rel_path} ---", "```", content, "```"]
              {:error, reason} ->
                ["--- File: #{rel_path} (Error reading file: #{inspect(reason)}) ---"]
            end
          end
        end)

    output_path = Path.join(cwd, @output_filename)
    File.write!(output_path, Enum.join(output, "\n"))
    {:ok, output_path}
  end

  # --- filter_files_by_cwd remains unchanged for now, it only uses Path ---
  @doc """
  Convert all tracked file paths (relative to repo root) to paths relative to the current working directory.
  """
  def filter_files_by_cwd(files, repo_root, cwd) do
    expanded_cwd = Path.expand(cwd)

    Enum.map(files, fn file_relative_to_repo ->
      calculate_relative_path(file_relative_to_repo, repo_root, expanded_cwd, cwd)
    end)
  end

  # --- Helper function to calculate relative path --- 
  defp calculate_relative_path(file_relative_to_repo, repo_root, expanded_cwd, cwd) do
    abs_path = Path.join(repo_root, file_relative_to_repo)
    expanded_abs_path = Path.expand(abs_path)

    relative_path = Path.relative_to(expanded_abs_path, expanded_cwd)

    # Fix for Path.relative_to returning absolute paths in some cases (e.g., macOS tmp dirs)
    if String.starts_with?(relative_path, "/") do
      # If result is absolute, check if original repo path contains the cwd's dir name
      if String.contains?(file_relative_to_repo, Path.basename(cwd)) do
        # Heuristic failed (e.g., file in subdir with same name as parent dir part)
        # Fallback to the absolute path from Path.relative_to
        relative_path
      else
        # Heuristic: Assume it's one level up if original path doesn't contain cwd base name
        "../" <> Path.basename(file_relative_to_repo)
      end
    else
      # Path.relative_to returned a relative path, use it
      relative_path
    end
  end

  defp list_all_files(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.flat_map(fn entry ->
          path = Path.join(dir, entry)

          if File.dir?(path) do
            list_all_files(path)
          else
            [path]
          end
        end)

      {:error, _} ->
        []
    end
  end

  # --- build_file_tree remains unchanged, it only uses Path/String/Map ---
  @doc """
  Builds a nested map representing the file tree structure.
  Input paths must be relative to the CWD and not contain '../'.
  """
  def build_file_tree(relative_files) do
    tree =
      Enum.reduce(relative_files, %{}, fn file_path, acc ->
        parts = Path.split(file_path)
        build_nested_map(acc, parts)
      end)

    {:ok, tree}
  rescue
    e -> {:error, "Failed to build file tree: #{inspect(e)}"}
  end

  defp build_nested_map(current_map, []) do
    # Should not happen with valid file paths
    current_map
  end

  defp build_nested_map(current_map, [file]) do
    Map.put(current_map, file, :file)
  end

  defp build_nested_map(current_map, [dir | rest]) do
    sub_tree = Map.get(current_map, dir, %{})
    updated_sub_tree = build_nested_map(sub_tree, rest)
    Map.put(current_map, dir, updated_sub_tree)
  end

  # --- format_tree remains unchanged, it only formats the map ---
  @doc """
  Formats the file tree map into a string list for display.
  """
  def format_tree(tree) do
    tree |> Map.to_list() |> Enum.sort() |> do_format_tree("", true)
  end

  defp do_format_tree([], _prefix, _is_last) do
    []
  end

  defp do_format_tree([{name, :file} | rest], prefix, is_last_parent) do
    connector = if is_last_parent && Enum.empty?(rest), do: "└── ", else: "├── "
    line = prefix <> connector <> name
    prefix <> if is_last_parent && Enum.empty?(rest), do: "    ", else: "│   "
    [line | do_format_tree(rest, prefix, is_last_parent)]
  end

  defp do_format_tree([{name, subtree} | rest], prefix, is_last_parent) when is_map(subtree) do
    is_last_child = Enum.empty?(rest)
    connector = if is_last_child, do: "└── ", else: "├── "
    line = prefix <> connector <> name
    children_prefix = prefix <> if is_last_child, do: "    ", else: "│   "

    children_lines =
      subtree |> Map.to_list() |> Enum.sort() |> do_format_tree(children_prefix, is_last_child)

    [line | children_lines] ++ do_format_tree(rest, prefix, is_last_parent)
  end

  defp generate_file_contents(relative_files, cwd, repo_root) do
    Enum.map(relative_files, fn relative_file ->
      # Resolve the absolute path correctly for reading
      absolute_path = resolve_file_path(relative_file, cwd, repo_root)

      if binary_file?(absolute_path) do
        ["--- File: #{relative_file} (Binary file ignored) ---"]
      else
        case read_file_content(relative_file, cwd) do
          {:ok, content} ->
            ["--- File: #{relative_file} ---", "```", content, "```"]
          {:error, reason} ->
            ["--- File: #{relative_file} (Error reading file: #{inspect(reason)}) ---"]
        end
      end
    end)
  end

  defp read_file_content(file_path, cwd) do
    full_path =
      case Path.type(file_path) do
        :absolute -> file_path
        :relative -> Path.join(cwd, file_path)
      end
    File.read(full_path)
  end

  # --- resolve_file_path remains unchanged, uses Path ---
  @doc false
  defp resolve_file_path(relative_file, cwd, _repo_root) do
    # If relative_file starts with ../, Path.expand/Path.join handles it correctly relative to cwd
    Path.expand(Path.join(cwd, relative_file))
  end

  defp binary_file?(file_path) do
    if File.regular?(file_path) do
      try do
        {:ok, chunk} = File.open(file_path, [:read], fn file ->
          IO.binread(file, 1024)
        end)
        is_binary(chunk) and String.contains?(chunk, "\0")
      rescue
        _ -> true
      end
    else
      false
    end
  end

  # End of defp
end
