# Prepx

Prepx is a command-line interface (CLI) tool that helps developers consolidate the codebase of a project (or a specific subdirectory within it) into a single text file. The primary use case for this consolidated file is to provide context to Large Language Models (LLMs).

## Features

- **Git Aware**: Only includes files that are tracked or untracked by Git, respecting `.gitignore` rules
- **Flexible Scope**: Can be run from any directory within a Git repository
- **Directory Summary**: Provides a tree-like summary of the directory structure
- **Binary File Handling**: Detects and skips binary files
- **Clear Formatting**: Clearly marks file content with start and end markers

## Installation

### Prerequisites

- Erlang/OTP (to run the escript)
- Git (must be available in your PATH)
- Elixir ~> 1.18 (for development only)

### Building from Source

1. Clone this repository
2. Build the escript:

```bash
cd prepx
mix deps.get
mix escript.build
```

3. The executable `prepx` will be generated in the project directory

### Adding to PATH

To use `prepx` from anywhere on your system, you need to add it to your PATH. Here are instructions for different operating systems:

#### macOS and Linux

Method 1: Copy to a directory already in your PATH:

```bash
# Copy to /usr/local/bin (might require sudo)
sudo cp prepx /usr/local/bin/

# Or to your user's bin directory if it exists and is in your PATH
cp prepx ~/bin/
```

Method 2: Create a symbolic link:

```bash
# Create a symbolic link in /usr/local/bin
sudo ln -s /full/path/to/your/prepx /usr/local/bin/prepx
```

Method 3: Add the directory containing prepx to your PATH (in your shell profile):

```bash
# For bash (add to ~/.bash_profile or ~/.bashrc)
echo 'export PATH="/path/to/directory/containing/prepx:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

# For zsh (add to ~/.zshrc)
echo 'export PATH="~/code/zimakki/prepx/:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Windows

Method 1: Copy to a directory in your PATH:

```powershell
# Copy to a directory that's already in your PATH, for example:
copy prepx.bat C:\Windows\System32\
```

Method 2: Add the directory to your PATH environment variable:

1. Right-click on 'This PC' or 'My Computer' and select 'Properties'
2. Click on 'Advanced system settings'
3. Click on 'Environment Variables'
4. Under 'System variables' or 'User variables', find the 'Path' variable, select it and click 'Edit'
5. Click 'New' and add the full path to the directory containing your prepx executable
6. Click 'OK' to close all dialogs

Method 3: Create a batch file wrapper and place it in a directory in your PATH:

```batch
@echo off
rem Save this as prepx.bat in a directory that's in your PATH
"C:\path\to\your\prepx" %*
```

To verify that `prepx` is correctly added to your PATH, open a new terminal or command prompt window and run:

```bash
prepx --version
```

## Usage

Simply navigate to any directory within a Git repository and run:

```bash
prepx
```

This will create a file named `llm_context.txt` in your current working directory containing:

1. A tree-like summary of the directory structure
2. The full content of all text files within the current directory (and subdirectories)
3. Markers for binary files (which are skipped)

### Example Output

```
# Directory Structure

└── lib
    ├── prepx
    │   ├── cli.ex
    │   └── core.ex
    └── prepx.ex

--- START FILE: lib/prepx.ex ---
defmodule Prepx do
  @moduledoc """
  Prepx is a CLI tool that consolidates a Git repository's codebase...
  """
end
--- END FILE: lib/prepx.ex ---

--- START FILE: lib/prepx/cli.ex ---
defmodule Prepx.CLI do
  ...
end
--- END FILE: lib/prepx/cli.ex ---

--- BINARY FILE (SKIPPED): assets/image.png ---
```

## Development

### Running Tests

```bash
mix test
```

### Project Structure

- `lib/prepx.ex` - Main module documentation
- `lib/prepx/cli.ex` - Command-line interface implementation
- `lib/prepx/core.ex` - Core functionality for file processing and output generation
- `test/` - Test suite and fixtures

## License

This project is licensed under the MIT License - see the LICENSE file for details.
