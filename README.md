# AI Coding Styles

This repository contains coding style guidelines and architectural patterns for AI-assisted Laravel development, specifically optimized for Laravel Boost workflows.

## Contents

- **ben-coding-style.md**: Comprehensive Laravel code style guide focusing on Action patterns, Domain-Driven Design, and clean architecture principles

## Key Principles

- **Action Pattern**: Single-purpose classes for business logic
- **Domain-Driven Organization**: Group related functionality by business domain
- **DRY Principle**: Eliminate code duplication through strategic abstraction
- **Enum-Driven Configuration**: Type-safe configuration and constants
- **Rich Models**: Domain-specific query methods in models
- **Thin Controllers**: Controllers handle only HTTP concerns

## Installation

Install these Laravel-specific guidelines to your project's AI configuration directory (optimized for Laravel Boost):

```bash
curl -sSL https://raw.githubusercontent.com/ben182/ai-styles/main/install.sh | bash
```

Or manually:

```bash
# Create directory
mkdir -p .ai/guidelines/

# Download guidelines
curl -sSL https://raw.githubusercontent.com/ben182/ai-styles/main/ben-coding-style.md -o .ai/guidelines/ben-coding-style.blade.php

echo "AI coding guidelines installed to .ai/guidelines/"
```

## Usage

Once installed, your AI assistant will have access to these coding standards and will follow them when generating or reviewing code in your project.