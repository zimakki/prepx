defmodule PrepxTest do
  use ExUnit.Case
  doctest Prepx

  @output_filename "llm_context.txt"

  setup do
    # Create a temporary directory for our test repo
    tmp_dir = Path.join(System.tmp_dir!(), "prepx_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(tmp_dir)

    # Set up test fixture structure
    setup_test_fixture(tmp_dir)

    on_exit(fn ->
      # Clean up temporary directory after test
      File.rm_rf!(tmp_dir)

      # Also clean up any output files in CWD if they exist
      output_file = Path.join(File.cwd!(), @output_filename)
      if File.exists?(output_file), do: File.rm!(output_file)
    end)

    %{tmp_dir: tmp_dir}
  end

  @tag :basic
  test "process from repo root", %{tmp_dir: tmp_dir} do
    # Run from repo root
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify directory summary
    assert String.contains?(content, "Directory Tree:")
    assert String.contains?(content, "├── .gitignore")
    assert String.contains?(content, "├── binary.bin")
    assert String.contains?(content, "├── dir1")
    assert String.contains?(content, "│   ├── dir1file.txt")
    assert String.contains?(content, "└── file1.txt")

    # Verify file markers and content
    assert String.contains?(content, "--- File: .gitignore ---")
    assert String.contains?(content, "--- File: binary.bin (Binary file ignored) ---")
    assert String.contains?(content, "--- File: dir1/dir1file.txt ---")
    assert String.contains?(content, "--- File: file1.txt ---")

    # Verify actual content (example)
    assert String.contains?(content, "This is file1 content")
    assert String.contains?(content, "This is dir1file content")
  end

  @tag :basic
  test "process from subdirectory", %{tmp_dir: tmp_dir} do
    # Run from subdirectory
    subdir_path = Path.join(tmp_dir, "dir1")
    {:ok, _} = Prepx.CLI.main([subdir_path])

    output_path = Path.join(subdir_path, @output_filename)
    content = File.read!(output_path)

    # Split content into tree and file contents sections
    [tree_section, file_contents_section] = String.split(content, "File Contents:\n", parts: 2)

    # Verify content includes all files, not just those in the current directory
    assert String.contains?(tree_section, "Directory Tree:")
    assert String.contains?(tree_section, "└── dir1file.txt")
    # Should not show parent items in tree
    refute String.contains?(tree_section, "../file1.txt")
    refute String.contains?(tree_section, "../.gitignore")

    assert String.contains?(file_contents_section, "File Contents:")
    # Should still contain content from parent dirs, marked relative
    assert String.contains?(file_contents_section, "--- File: ../.gitignore ---")

    assert String.contains?(
             file_contents_section,
             "--- File: ../binary.bin (Binary file ignored) ---"
           )

    assert String.contains?(file_contents_section, "--- File: dir1file.txt ---")
    assert String.contains?(file_contents_section, "--- File: ../file1.txt ---")

    # Verify actual content (example)
    assert String.contains?(file_contents_section, "This is file1 content")
    assert String.contains?(file_contents_section, "This is dir1file content")
  end

  @tag :file_system
  test "gitignore exclusion", %{tmp_dir: tmp_dir} do
    # Run from repo root
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify ignored file is not included as a file content
    refute String.contains?(content, "--- File: ignored.txt ---")
    refute String.contains?(content, "This file should be ignored")
  end

  @tag :file_system
  test "binary file detection", %{tmp_dir: tmp_dir} do
    # Run from repo root
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Check tree includes binary file
    assert String.contains?(content, "├── binary.bin")
    # Check contents section marks binary file correctly
    assert String.contains?(content, "--- File: binary.bin (Binary file ignored) ---")
    # Ensure content of binary file is not included
    refute String.contains?(content, "<<0, 1, 2>>")
  end

  @tag :file_system
  test "empty directory handling", %{tmp_dir: tmp_dir} do
    # Create an empty directory
    empty_dir = Path.join(tmp_dir, "empty_dir")
    File.mkdir!(empty_dir)

    # Run prepx from the parent directory
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify that the empty directory is included in the directory tree
    assert String.contains?(content, "├── empty_dir")
    # Verify that there is no file content for the empty directory
    refute String.contains?(content, "--- File: empty_dir ---")
  end

  @tag :file_system
  test "deeply nested directories", %{tmp_dir: tmp_dir} do
    # Create a deeply nested directory structure
    nested_dir = Path.join(tmp_dir, "dir1")
    nested_dir = Path.join(nested_dir, "dir2")
    nested_dir = Path.join(nested_dir, "dir3")
    File.mkdir_p!(nested_dir)
    File.write!(Path.join(nested_dir, "nested_file.txt"), "This is a nested file.")

    # Run prepx from the parent directory
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify that the nested directory structure is correctly displayed in the tree
    assert String.contains?(content, "│   └── dir1")
    assert String.contains?(content, "│       └── dir2")
    assert String.contains?(content, "│           └── dir3")
    assert String.contains?(content, "│               └── nested_file.txt")
    # Verify that the content of the nested file is included
    assert String.contains?(content, "--- File: dir1/dir2/dir3/nested_file.txt ---")
    assert String.contains?(content, "This is a nested file.")
  end

  @tag :file_system
  test "file name edge cases", %{tmp_dir: tmp_dir} do
    # Create files with spaces and special characters in their names
    space_file = Path.join(tmp_dir, "file with spaces.txt")
    special_file = Path.join(tmp_dir, "file!@#$%^&*.txt")
    File.write!(space_file, "This file has spaces in its name.")
    File.write!(special_file, "This file has special characters in its name.")

    # Run prepx from the parent directory
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify that the files with spaces and special characters are correctly displayed
    assert String.contains?(content, "├── file with spaces.txt")
    assert String.contains?(content, "├── file!@#$%^&*.txt")
    assert String.contains?(content, "--- File: file with spaces.txt ---")
    assert String.contains?(content, "--- File: file!@#$%^&*.txt ---")
    assert String.contains?(content, "This file has spaces in its name.")
    assert String.contains?(content, "This file has special characters in its name.")
  end

  @tag :content
  test "file content encoding", %{tmp_dir: tmp_dir} do
    # Create a UTF-8 encoded file
    utf8_file = Path.join(tmp_dir, "utf8_file.txt")
    File.write!(utf8_file, "This is a UTF-8 file with some special characters: éàçüö.")

    # Run prepx from the parent directory
    {:ok, _} = Prepx.CLI.main([tmp_dir])

    output_path = Path.join(tmp_dir, @output_filename)
    content = File.read!(output_path)

    # Verify that the UTF-8 content is correctly displayed
    assert String.contains?(content, "--- File: utf8_file.txt ---")
    assert String.contains?(content, "This is a UTF-8 file with some special characters: éàçüö.")
  end

  @tag :git
  test "git repository boundary detection", %{tmp_dir: tmp_dir} do
    # Create a directory *outside* the git repository
    external_dir = Path.join(Path.dirname(tmp_dir), "external_dir")
    File.mkdir_p!(external_dir)
    File.write!(Path.join(external_dir, "external_file.txt"), "This is an external file.")

    # Run prepx from the external directory
    {:ok, _} = Prepx.CLI.main([external_dir])

    output_path = Path.join(external_dir, @output_filename)
    content = File.read!(output_path)

    # Verify that prepx still functions correctly and displays the external file
    assert String.contains?(content, "Directory Tree:")
    assert String.contains?(content, "└── external_file.txt")
    assert String.contains?(content, "--- File: external_file.txt ---")
    assert String.contains?(content, "This is an external file.")
  end

  @tag :git
  test "file path resolution in subdirectories", %{tmp_dir: tmp_dir} do
    # Setup complex structure
    setup_repo(tmp_dir)
    components_dir = Path.join(tmp_dir, "components")

    # Run from components subdirectory
    {:ok, _} = Prepx.CLI.main([components_dir])

    output_path = Path.join(components_dir, @output_filename)
    content = File.read!(output_path)

    # Split content into tree and file contents sections
    [tree_section, file_contents_section] = String.split(content, "File Contents:\n", parts: 2)

    # Check Tree (should only contain button.ex relative to components_dir)
    assert String.contains?(tree_section, "Directory Tree:")
    assert String.contains?(tree_section, "└── button.ex")
    refute String.contains?(tree_section, "../file1.txt")

    # Check Contents (should include files from parent, marked relative)
    assert String.contains?(file_contents_section, "File Contents:")
    assert String.contains?(file_contents_section, "--- File: ../.gitignore ---")

    assert String.contains?(
             file_contents_section,
             "--- File: ../binary.bin (Binary file ignored) ---"
           )

    # Test deeper nesting
    assert String.contains?(file_contents_section, "--- File: ../dir1/dir1file.txt ---")
    assert String.contains?(file_contents_section, "--- File: ../file1.txt ----")
    assert String.contains?(file_contents_section, "--- File: button.ex ---")

    # Check actual content
    assert String.contains?(file_contents_section, "defmodule Button do")
    assert String.contains?(file_contents_section, "This is file1 content")
    assert String.contains?(file_contents_section, "ignored.txt")
  end

  # Helper function to set up our test fixture
  defp setup_test_fixture(dir) do
    # Create files in root
    File.write!(Path.join(dir, "file1.txt"), "This is file1 content")
    File.write!(Path.join(dir, "binary.bin"), <<0, 1, 2, 3>>)
    File.write!(Path.join(dir, "ignored.txt"), "This should be ignored")

    # Create directory structure
    dir1 = Path.join(dir, "dir1")
    File.mkdir_p!(dir1)
    File.write!(Path.join(dir1, "dir1file.txt"), "This is dir1file content")

    # Initialize git repository
    System.cmd("git", ["init"], cd: dir)
    System.cmd("git", ["add", "file1.txt", "binary.bin", "dir1"], cd: dir)

    # Create .gitignore to exclude ignored.txt
    File.write!(Path.join(dir, ".gitignore"), "ignored.txt")
    System.cmd("git", ["add", ".gitignore"], cd: dir)

    # Set git config for the test
    System.cmd("git", ["config", "user.name", "Test User"], cd: dir)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: dir)
    System.cmd("git", ["commit", "-m", "Initial commit"], cd: dir)
  end

  defp setup_repo(tmp_dir) do
    # Create files in root
    File.write!(Path.join(tmp_dir, "file1.txt"), "This is file1 content")
    File.write!(Path.join(tmp_dir, "binary.bin"), <<0, 1, 2, 3>>)
    File.write!(Path.join(tmp_dir, "ignored.txt"), "This should be ignored")

    # Create directory structure
    dir1 = Path.join(tmp_dir, "dir1")
    File.mkdir_p!(dir1)
    File.write!(Path.join(dir1, "dir1file.txt"), "This is dir1file content")

    # Initialize git repository
    System.cmd("git", ["init"], cd: tmp_dir)
    System.cmd("git", ["add", "file1.txt", "binary.bin", "dir1"], cd: tmp_dir)

    # Create .gitignore to exclude ignored.txt
    File.write!(Path.join(tmp_dir, ".gitignore"), "ignored.txt")
    System.cmd("git", ["add", ".gitignore"], cd: tmp_dir)

    # Set git config for the test
    System.cmd("git", ["config", "user.name", "Test User"], cd: tmp_dir)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: tmp_dir)
    System.cmd("git", ["commit", "-m", "Initial commit"], cd: tmp_dir)
  end
end
