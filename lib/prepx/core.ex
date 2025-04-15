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

    tracked_files =
      all_files
      |> Enum.filter(&git_module.in_git_repo?/1)
      |> Enum.map(fn abs_path ->
        rel_path = Path.relative_to(abs_path, cwd)
        {abs_path, rel_path}
      end)

    tree_map =
      tracked_files
      |> Enum.map(fn {_, rel_path} -> rel_path end)
      |> build_file_tree()
      |> case do
        {:ok, map} -> map
        map when is_map(map) -> map
        _ -> %{}
      end

    output =
      ["Directory Tree:", "```", format_tree(tree_map), "```", "", "File Contents:"] ++
        Enum.flat_map(tracked_files, fn {abs_path, rel_path} ->
          process_file(abs_path, rel_path)
        end)

    output_path = Path.join(cwd, @output_filename)
    File.write!(output_path, Enum.join(output, "\n"))
    {:ok, output_path}
  end

  defp process_file(abs_path, rel_path) do
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
  end

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

  defp binary_file?(file_path) do
    if File.regular?(file_path) do
      try do
        {:ok, chunk} =
          File.open(file_path, [:read], fn file ->
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

  defp list_all_files(dir) do
    File.ls!(dir)
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)

      cond do
        File.dir?(path) ->
          list_all_files(path)

        File.regular?(path) ->
          [path]

        true ->
          []
      end
    end)
  end
end
