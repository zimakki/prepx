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
4. Move it to a directory in your PATH to use it from anywhere:

```bash
# Example (you may need sudo depending on your setup)
cp prepx /usr/local/bin/
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
