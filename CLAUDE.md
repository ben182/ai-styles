# CLAUDE.md

Laravel coding style guidelines repository for AI-assisted development. Contains `ben-coding-style.md` guide installable via `./install.sh`.

## Architecture Patterns

1. **Action Pattern**: Single-purpose `app/Actions/` classes with `execute()` method
2. **Domain-Driven**: Group by business domain (`app/Domain/User/`, etc.)
3. **DRY Principle**: Strategic abstraction via base classes/traits
4. **Enum Configuration**: Type-safe PHP enums with `getLabel()`, `canTransitionTo()` methods
5. **Rich Models**: Domain-specific query/relationship methods
6. **Thin Controllers**: Delegate to Actions, handle only HTTP concerns

## Code Conventions

- Use `Model::query()->method()` not `Model::method()`
- Descriptive parameter/variable names, no abbreviations
- Prefer Laravel collections and functional programming

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/ben182/ai-styles/main/install.sh | bash
```

Downloads guide to target project's `.ai/guidelines/` directory.