# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains coding style guidelines and architectural patterns for AI-assisted Laravel development, specifically optimized for Laravel Boost workflows. The primary deliverable is a comprehensive Laravel code style guide (`ben-coding-style.md`) that can be installed into Laravel projects.

## Repository Structure

- **README.md**: Repository overview and installation instructions
- **ben-coding-style.md**: Comprehensive Laravel code style guide (9.3KB) focusing on Action patterns, Domain-Driven Design, and clean architecture principles
- **install.sh**: Installation script that downloads the coding style guide to `.ai/guidelines/` directory in target projects

## Key Architectural Concepts Covered

The style guide emphasizes:

1. **Action Pattern**: Single-purpose classes in `app/Actions/` for business logic with `execute()` method
2. **Domain-Driven Organization**: Group related functionality by business domain (`app/Domain/User/`, `app/Domain/Order/`, etc.)
3. **DRY Principle**: Strategic abstraction through base classes, traits, and helper methods
4. **Enum-Driven Configuration**: Type-safe configuration using PHP enums with methods like `getLabel()` and `canTransitionTo()`
5. **Rich Models**: Domain-specific query methods and relationship methods in models
6. **Thin Controllers**: Controllers handle only HTTP concerns, delegate to Actions

## Development Commands

This repository is a documentation/guidelines repository with no build process, tests, or linting commands. The only operational script is:

- `./install.sh`: Installs the coding guidelines to a target project's `.ai/guidelines/` directory

## Code Style Conventions

The guide enforces specific conventions:

- **Descriptive Parameter Names**: Avoid abbreviations, use full descriptive names matching type names
- **Eloquent Query Prefix**: Always use `Model::query()->method()` instead of `Model::method()` for better IDE support
- **Collection Usage**: Prefer Laravel collections and functional programming patterns
- **Variable Naming**: Use complete, unambiguous variable names

## Installation Workflow

The repository is designed to be consumed by other Laravel projects:

```bash
curl -sSL https://raw.githubusercontent.com/ben182/ai-styles/main/install.sh | bash
```

This downloads `ben-coding-style.md` as `ben-coding-style.blade.php` to the target project's `.ai/guidelines/` directory, making it available to AI assistants working on that Laravel project.

## Claude Code Permissions

The repository includes Claude Code settings that allow `Bash(chmod:*)` commands for managing file permissions during installation processes.