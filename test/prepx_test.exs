defmodule PrepxTest do
  use ExUnit.Case, async: false
  doctest Prepx

  import Mox
  setup :verify_on_exit!

  @output_filename "llm_context.txt"

  # Directly run the process function with different arguments
  # instead of using CLI.main which has System.halt()
  setup do
    # Create a temporary directory for our test repo
    tmp_dir = Path.join(System.tmp_dir!(), "prepx_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(tmp_dir)

    # Set up test fixture structure
    setup_test_fixture(tmp_dir)

    on_exit(fn ->
      # Clean up temporary directory after test
      File.cd!(System.tmp_dir!())
      File.rm_rf!(tmp_dir)

      # Also clean up any output files in CWD if they exist
      output_file = Path.join(File.cwd!(), @output_filename)
      if File.exists?(output_file), do: File.rm!(output_file)
    end)

    %{tmp_dir: tmp_dir}
  end

  # test "failin test" do
  #   assert false
  # end

  test "process from repo root", %{tmp_dir: tmp_dir} do
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(tmp_dir, @output_filename)
      content = File.read!(output_path)
      refute Regex.match?(~r/--- File: (.*\/)?ignored\.txt( |$)/, content)
      assert String.contains?(content, "Directory Tree:")
      assert String.contains?(content, "file1.txt")
      assert String.contains?(content, "binary.bin")
      assert String.contains?(content, "dir1file.txt")
      assert String.contains?(content, "(Binary file ignored)")
      assert String.contains?(content, "This is file1 content")
      assert String.contains?(content, "This is dir1file content")
    after
      File.cd!(original_dir)
    end
  end

  test "process from subdirectory", %{tmp_dir: tmp_dir} do
    IO.puts("Running process from subdirectory test")
    subdir_path = Path.join(tmp_dir, "dir1")
    original_dir = File.cwd!()
    File.cd!(subdir_path)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(subdir_path, @output_filename)
      content = File.read!(output_path)
      [tree_section, file_contents_section] = String.split(content, "File Contents:\n", parts: 2)
      assert String.contains?(tree_section, "dir1file.txt")
      assert String.contains?(file_contents_section, "This is dir1file content")
      refute Regex.match?(~r/--- File: (.*\/)?ignored\.txt( |$)/, content)
    after
      File.cd!(original_dir)
    end
  end

  test "gitignore exclusion", %{tmp_dir: tmp_dir} do
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(tmp_dir, @output_filename)
      content = File.read!(output_path)
      refute Regex.match?(~r/--- File: (.*\/)?ignored\.txt( |$)/, content)
    after
      File.cd!(original_dir)
    end
  end

  test "binary file detection", %{tmp_dir: tmp_dir} do
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    try do
      Prepx.GitBehaviourMock |> stub(:in_git_repo?, fn _ -> true end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(tmp_dir, @output_filename)
      content = File.read!(output_path)
      # Accept either the absolute path or just the filename in the output
      assert Regex.match?(~r/--- File: (.*\/)?binary\.bin \(Binary file ignored\) ---/, content)
    after
      File.cd!(original_dir)
    end
  end

  test "empty directory handling", %{tmp_dir: tmp_dir} do
    empty_dir = Path.join(tmp_dir, "empty_dir")
    File.mkdir!(empty_dir)
    original_dir = File.cwd!()
    File.cd!(empty_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(empty_dir, @output_filename)
      content = File.read!(output_path)
      refute String.contains?(content, "--- File: empty_dir ---")
    after
      File.cd!(original_dir)
    end
  end

  test "deeply nested directories", %{tmp_dir: tmp_dir} do
    nested_dir = Path.join([tmp_dir, "dir1", "dir2", "dir3"])
    File.mkdir_p!(nested_dir)
    nested_file = Path.join(nested_dir, "nested.txt")
    File.write!(nested_file, "This is a nested file.")
    original_dir = File.cwd!()
    File.cd!(nested_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(nested_dir, @output_filename)
      content = File.read!(output_path)
      assert String.contains?(content, "This is a nested file.")
    after
      File.cd!(original_dir)
    end
  end

  test "file name edge cases", %{tmp_dir: tmp_dir} do
    space_file = Path.join(tmp_dir, "file with spaces.txt")
    special_file = Path.join(tmp_dir, "file!@#$%^&*.txt")
    File.write!(space_file, "This file has spaces in its name.")
    File.write!(special_file, "This file has special characters in its name.")
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(tmp_dir, @output_filename)
      content = File.read!(output_path)
      assert String.contains?(content, "file with spaces.txt")
      assert String.contains?(content, "file!@#$%^&*.txt")
      assert String.contains?(content, "This file has spaces in its name.")
      assert String.contains?(content, "This file has special characters in its name.")
    after
      File.cd!(original_dir)
    end
  end

  test "file content encoding", %{tmp_dir: tmp_dir} do
    utf8_file = Path.join(tmp_dir, "utf8_file.txt")
    File.write!(utf8_file, "This is a UTF-8 file with some special characters: éàçüö.")
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(tmp_dir, @output_filename)
      content = File.read!(output_path)
      assert String.contains?(content, "This is a UTF-8 file with some special characters: éàçüö.")
    after
      File.cd!(original_dir)
    end
  end

  test "git repository boundary detection", %{tmp_dir: tmp_dir} do
    external_dir = Path.join(System.tmp_dir!(), "external_dir")
    File.mkdir_p!(external_dir)
    File.write!(Path.join(external_dir, "external_file.txt"), "This is an external file.")
    original_dir = File.cwd!()
    File.cd!(external_dir)
    try do
      {:ok, _} = Prepx.Core.process(Prepx.GitInterface)
      output_path = Path.join(external_dir, @output_filename)
      content = File.read!(output_path)
      assert String.contains?(content, "File Contents:")
    after
      File.cd!(original_dir)
      File.rm_rf!(external_dir)
    end
  end

  test "file path resolution in subdirectories", %{tmp_dir: tmp_dir} do
    components_dir = Path.join(tmp_dir, "components")
    File.mkdir_p!(components_dir)
    File.write!(Path.join(components_dir, "component.txt"), "This is a component file.")
    original_dir = File.cwd!()
    File.cd!(components_dir)
    try do
      Prepx.GitBehaviourMock
      |> stub(:in_git_repo?, fn path ->
        not String.ends_with?(path, "ignored.txt")
      end)
      {:ok, _} = Prepx.Core.process(Prepx.GitBehaviourMock)
      output_path = Path.join(components_dir, @output_filename)
      content = File.read!(output_path)
      assert String.contains?(content, "Directory Tree:")
      assert String.contains?(content, "└── component.txt")
      refute String.contains?(content, "../file1.txt")
    after
      File.cd!(original_dir)
    end
  end

  # Helper function to set up our test fixture
  defp setup_test_fixture(tmp_dir) do
    # Create files in root
    File.write!(Path.join(tmp_dir, "file1.txt"), "This is file1 content")
    File.write!(Path.join(tmp_dir, "binary.bin"), <<0, 1, 2, 3>>)
    File.write!(Path.join(tmp_dir, "ignored.txt"), "This should be ignored")

    # Create directory structure
    dir1 = Path.join(tmp_dir, "dir1")
    File.mkdir_p!(dir1)
    File.write!(Path.join(dir1, "dir1file.txt"), "This is dir1file content")

    # Create .gitignore to exclude ignored.txt
    File.write!(Path.join(tmp_dir, ".gitignore"), "ignored.txt")
  end
end
