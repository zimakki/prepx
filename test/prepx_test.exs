defmodule PrepxTest do
  use ExUnit.Case
  doctest Prepx

  alias Prepx.Core

  @output_filename "llm_context.txt"

  setup do
    # Create a temporary directory for our test repo
    tmp_dir = Path.join(System.tmp_dir!(), "prepx_test_#{:rand.uniform(1000000)}")
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
      assert File.exists?(output_path)
      
      content = File.read!(output_path)
      
      # Verify only files from subdirectory are included
      assert String.contains?(content, "--- START FILE: file2.txt ---")
      refute String.contains?(content, "--- START FILE: file1.txt ---")
      
      # Verify directory summary only shows subdirectory structure
      assert String.contains?(content, "# Directory Structure")
      assert String.contains?(content, "└── file2.txt")
      refute String.contains?(content, "└── dir1")
    after
      # Return to the original directory
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
  defp setup_test_fixture(tmp_dir) do
    # Create directories
    File.mkdir_p!(Path.join(tmp_dir, "dir1"))
    
    # Create files
    File.write!(Path.join(tmp_dir, "file1.txt"), "This is file1 content")
    File.write!(Path.join(tmp_dir, "dir1/file2.txt"), "This is file2 content")
    File.write!(Path.join(tmp_dir, "ignored.txt"), "This file should be ignored")
    
    # Create a "binary" file with null bytes
    File.write!(Path.join(tmp_dir, "binary.bin"), <<0, 1, 2, 3, 0>>)
    
    # Create .gitignore
    File.write!(Path.join(tmp_dir, ".gitignore"), "ignored.txt")
    
    # Initialize Git repo
    System.cmd("git", ["init"], cd: tmp_dir)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: tmp_dir)
    System.cmd("git", ["config", "user.name", "Test User"], cd: tmp_dir)
    System.cmd("git", ["add", "."], cd: tmp_dir)
    System.cmd("git", ["commit", "-m", "Initial commit"], cd: tmp_dir)
  end
end
