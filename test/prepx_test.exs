defmodule PrepxTest do
  use ExUnit.Case
  doctest Prepx

  alias Prepx.Core

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

  test "process from repo root", %{tmp_dir: tmp_dir} do
    # Change to the tmp_dir and run the process
    original_dir = File.cwd!()
    File.cd!(tmp_dir)

    try do
      {:ok, output_path} = Core.process()
      assert Path.basename(output_path) == @output_filename
      assert File.exists?(output_path)

      content = File.read!(output_path)

      # Verify directory summary
      assert String.contains?(content, "# Directory Structure")
      assert String.contains?(content, "└── dir1")
      assert String.contains?(content, "└── file1.txt")

      # Verify file markers and content
      assert String.contains?(content, "--- START FILE: file1.txt ---")
      assert String.contains?(content, "This is file1 content")
      assert String.contains?(content, "--- END FILE: file1.txt ---")

      # Verify binary file handling
      assert String.contains?(content, "--- BINARY FILE (SKIPPED): binary.bin ---")

      # Verify ignored file exclusion
      refute String.contains?(content, "--- START FILE: ignored.txt ---")
    after
      # Return to the original directory
      File.cd!(original_dir)
    end
  end

  test "process from subdirectory", %{tmp_dir: tmp_dir} do
    # Change to a subdirectory and run the process
    original_dir = File.cwd!()
    subdir_path = Path.join(tmp_dir, "dir1")
    File.cd!(subdir_path)

    try do
      {:ok, output_path} = Core.process()
      assert Path.basename(output_path) == @output_filename
      
      content = File.read!(output_path)
      
      # Verify content includes all files, not just those in the current directory
      assert String.contains?(content, "--- START FILE: dir1file.txt ---")
      assert String.contains?(content, "This is dir1file content")
      assert String.contains?(content, "--- END FILE: dir1file.txt ---")
      
      # Should still include files from parent directories
      assert String.contains?(content, "--- START FILE: ../file1.txt ---")
      assert String.contains?(content, "This is file1 content")
    after
      # Return to the original directory
      File.cd!(original_dir)
    end
  end
  
  # New test to specifically check for the subdirectory file path issue
  test "file path resolution in subdirectories", %{tmp_dir: tmp_dir} do
    # Create a project-like structure with subdirectories
    nested_dir = Path.join([tmp_dir, "lib", "components"])
    File.mkdir_p!(nested_dir)
    
    # Add a file in the nested directory
    component_file = Path.join(nested_dir, "button.ex")
    File.write!(component_file, "defmodule Button do\n  def render, do: \"Button\"\nend\n")
    
    # Initialize git repo and add files
    original_dir = File.cwd!()
    File.cd!(tmp_dir)
    
    System.cmd("git", ["init"])
    System.cmd("git", ["add", "."])
    System.cmd("git", ["config", "user.name", "Test User"])
    System.cmd("git", ["config", "user.email", "test@example.com"])
    System.cmd("git", ["commit", "-m", "Initial commit"])
    
    # Change to the lib directory
    lib_dir = Path.join(tmp_dir, "lib")
    File.cd!(lib_dir)
    
    try do
      {:ok, output_path} = Core.process()
      content = File.read!(output_path)
      
      # The components/button.ex file should be included in the output
      assert String.contains?(content, "--- START FILE: components/button.ex ---")
      assert String.contains?(content, "defmodule Button do")
    after
      File.cd!(original_dir)
    end
  end

  test "gitignore exclusion", %{tmp_dir: tmp_dir} do
    # Change to the tmp_dir and run the process
    original_dir = File.cwd!()
    File.cd!(tmp_dir)

    try do
      {:ok, output_path} = Core.process()
      content = File.read!(output_path)

      # Verify ignored file is not included as a file content
      refute String.contains?(content, "--- START FILE: ignored.txt ---")
      refute String.contains?(content, "This file should be ignored")
    after
      # Return to the original directory
      File.cd!(original_dir)
    end
  end

  test "binary file detection", %{tmp_dir: tmp_dir} do
    original_dir = File.cwd!()
    File.cd!(tmp_dir)

    try do
      {:ok, output_path} = Core.process()
      content = File.read!(output_path)

      # Verify binary file is detected and skipped
      assert String.contains?(content, "--- BINARY FILE (SKIPPED): binary.bin ---")
      refute String.contains?(content, "--- START FILE: binary.bin ---")
    after
      File.cd!(original_dir)
    end
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
end
