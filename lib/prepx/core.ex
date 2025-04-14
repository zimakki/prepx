defmodule Prepx.Core do
  @moduledoc """
  Core functionality for the Prepx tool.

  This module handles the processing of Git repositories to generate
  a consolidated text file for LLM context.
  """

  @output_filename "llm_context.txt"

  @doc """
  Process the current working directory and create the LLM context file.

  Requires a module implementing FileSystemBehaviour.

  ## Returns

  * `{:ok, output_path}` - The path to the created context file
  * `{:error, reason}` - An error message if processing failed
  """
  def process(fs_module \\ Prepx.FileSystemReal) when is_atom(fs_module) do
    with {:ok, repo_root} <- Prepx.Git.get_git_repo_root(),
         # Use injected module
         {:ok, cwd} <- fs_module.cwd(),
         {:ok, tracked_files} <- Prepx.Git.get_git_tracked_files(repo_root),
         # Get all files relative to cwd for content generation
         relative_files_for_content = filter_files_by_cwd(tracked_files, repo_root, cwd),
         # Filter files for directory tree (only current dir and subdirs)
         relative_files_for_tree =
           Enum.reject(relative_files_for_content, &String.starts_with?(&1, "../")),
         # Build tree using only files at/below cwd
         {:ok, file_tree} <- build_file_tree(relative_files_for_tree),
         # Generate output using the full list (including ../) for file content
         # Pass fs_module
         {:ok, output_path} <-
           generate_output_file(fs_module, file_tree, relative_files_for_content, cwd, repo_root) do
      {:ok, output_path}
    else
      {:error, reason} -> {:error, reason}
    end
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

  # --- generate_output_file needs fs_module ---
  defp generate_output_file(fs_module, file_tree, relative_files_for_content, cwd, repo_root) do
    output_path = Path.join(cwd, @output_filename)
    formatted_tree = format_tree(file_tree)
    # Generate content for all files, including those potentially outside cwd (using ../)
    file_contents =
      generate_file_contents(fs_module, relative_files_for_content, cwd, repo_root)

    output_content =
      ["Directory Tree:", "```", formatted_tree, "```", "\nFile Contents:", file_contents]
      |> List.flatten()
      |> Enum.join("\n")

    try do
      _ = fs_module.write!(output_path, output_content)
      {:ok, output_path}
    rescue
      e in File.Error ->
        {:error, "Failed to write output file #{output_path}: #{inspect(e)}"}
    end
  end

  # --- generate_file_contents needs fs_module ---
  defp generate_file_contents(fs_module, relative_files, cwd, repo_root) do
    Enum.map(relative_files, fn relative_file ->
      # Resolve the absolute path correctly for reading
      absolute_path = resolve_file_path(relative_file, cwd, repo_root)

      if binary_file?(fs_module, absolute_path) do
        ["--- File: #{relative_file} (Binary file ignored) ---"]
      else
        # Assign result to variable first, then return
        result =
          try do
            # Use injected module
            content = fs_module.read!(absolute_path)
            ["--- File: #{relative_file} ---", "```", content, "```"]
          rescue
            e in File.Error ->
              # IO.inspect(e, label: "File read error for #{absolute_path}")
              ["--- File: #{relative_file} (Error reading file: #{inspect(e)}) ---"]
          end

        # End of try/rescue

        # Return the result variable
        result
      end
    end)
  end

  # --- resolve_file_path remains unchanged, uses Path ---
  @doc false
  defp resolve_file_path(relative_file, cwd, _repo_root) do
    # If relative_file starts with ../, Path.expand/Path.join handles it correctly relative to cwd
    Path.expand(Path.join(cwd, relative_file))
  end

  # --- binary_file? needs fs_module ---
  defp binary_file?(fs_module, file_path) do
    # First check if it's a regular file, directories/symlinks aren't binary content files
    # Use injected module
    if fs_module.regular?(file_path) do
      # It's a regular file, try reading it
      try do
        # Read up to 1024 bytes
        # Use injected module
        chunk = fs_module.read!(file_path)
        # Check for null byte
        String.contains?(chunk, "\0")
      rescue
        # If we can't even read the file, treat it as binary/unreadable
        File.Error -> true
      end

      # End of try/rescue
    else
      # Not a regular file (dir, symlink etc.) -> treat as binary/ignorable
      # Treat non-regular files (like dirs, symlinks that might be broken) as ignorable/binary
      true
    end

    # End of if/else
  end

  # End of defp
end
