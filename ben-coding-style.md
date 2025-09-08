# Ben's Laravel Code Style Guide

Architectural patterns and conventions for Laravel applications. Follow these principles for clean, maintainable code.

## Core Architectural Principles

### 1. Action Pattern (Primary Pattern)
Actions are single-purpose classes that encapsulate business logic operations.

```php
<?php
namespace App\Actions;

class CreateUserAction
{
    public function __construct(
        protected UserService $userService,
        protected NotificationService $notificationService
    ) {}
    
    public function execute(array $userData): User
    {
        $user = $this->userService->create($userData);
        $this->notificationService->sendWelcomeEmail($user);
        return $user;
    }
}
```

**Key Rules:**
- Actions live in `app/Actions/`
- Single responsibility principle - each Action has ONE specific purpose
- Use dependency injection in constructor
- Main method is always `execute()`
- Actions orchestrate between services/models

### 2. View Model Pattern
View models prepare and provide data specifically for views, keeping controllers thin.

```php
<?php
namespace App\ViewModels;

class PostFormViewModel
{
    public function __construct(
        private User $user,
        private ?Post $post = null,
    ) {}
    
    public function post(): Post
    {
        return $this->post ?? new Post();
    }
    
    public function categories(): Collection
    {
        return Category::query()
            ->allowedForUser($this->user)
            ->get();
    }
}
```

**Controller Integration:**
```php
public function create()
{
    $viewModel = new PostFormViewModel(current_user());
    return view('blog.form', compact('viewModel'));
}
```

**Benefits:**
- Reusability across create/edit/show contexts
- Separation of concerns
- DRY principle compliance

### 3. Domain-Driven Organization (DDD)
Organize related functionality into domain-specific folders.

```
app/
├── Actions/
├── ViewModels/
├── Domain/
│   ├── User/
│   │   ├── Models/
│   │   ├── Services/  
│   │   ├── Actions/
│   │   └── ViewModels/
│   └── Order/
│       ├── Models/
│       └── Services/
└── Shared/
    └── Services/
```

### 4. DRY Principle
Avoid code duplication through strategic abstraction.

```php
// Base classes for common functionality
abstract class BaseService
{
    protected function validateRequired(array $data, array $required): void
    {
        // Shared validation logic
    }
}

// Traits for reusable behavior
trait HasStatus 
{
    public function isActive(): bool
    {
        return $this->status === 'active';
    }
}
```

### 5. Console Commands as Thin Orchestrators
Commands delegate to Actions rather than contain business logic.

```php
class ProcessOrdersCommand extends Command
{
    public function handle(ProcessOrdersAction $action): void
    {
        $result = $action->execute();
        $this->info("Processed {$result->count()} orders");
    }
}
```

### 6. Artisan Call Commands
Always use `::class` for better IDE support:

```php
// ❌ Bad
Artisan::call('orders:process');

// ✅ Good
Artisan::call(ProcessOrdersCommand::class);
```

## Code Style Conventions

### Variable and Parameter Naming
Use descriptive, unambiguous names:

```php
// ❌ Bad
public function handle(SyncFeiertageAction $action): int

// ✅ Good
public function handle(SyncFeiertageAction $syncFeiertageAction): int
```

### Eloquent Query Methods
Always prefix with `query()` for better IDE support:

```php
// ❌ Bad
$user = User::updateOrCreate(['email' => $email], ['name' => $name]);

// ✅ Good
$user = User::query()->updateOrCreate(['email' => $email], ['name' => $name]);
```

### Enum-Driven Configuration
Use enums instead of arrays or constants:

```php
enum OrderStatus: string
{
    case PENDING = 'pending';
    case CONFIRMED = 'confirmed';
    case SHIPPED = 'shipped';
    
    public function getLabel(): string
    {
        return match ($this) {
            self::PENDING => 'Pending Payment',
            self::CONFIRMED => 'Order Confirmed', 
            self::SHIPPED => 'Shipped',
        };
    }
    
    public function canTransitionTo(OrderStatus $status): bool
    {
        return match ($this) {
            self::PENDING => $status === self::CONFIRMED,
            self::CONFIRMED => $status === self::SHIPPED,
            self::SHIPPED => false,
        };
    }
}
```

## Database & Model Patterns

### Models ≠ Business Logic
Models focus on data representation, not business logic.

```php
// ❌ Bad - Business logic in model
class Invoice extends Model
{
    public function getTotalPriceAttribute(): int
    {
        return $this->invoiceLines->reduce(
            fn (int $total, InvoiceLine $line) => $total + $line->total_price,
            0
        );
    }
}

// ✅ Good - Business logic in Actions
class CalculateInvoiceTotalAction
{
    public function execute(Invoice $invoice): int
    {
        $totalPrice = $invoice->invoiceLines->sum('total_price');
        $invoice->update(['total_price' => $totalPrice]);
        return $totalPrice;
    }
}
```

### Rich Model Data Access
Models provide rich data access methods without heavy business logic:

```php
class User extends Model 
{
    // ✅ Good - Rich relationship methods
    public function activeOrders(): HasMany
    {
        return $this->orders()->where('status', '!=', OrderStatus::CANCELLED);
    }
    
    // ✅ Good - Simple query scopes
    public function scopeVerified($query)
    {
        return $query->whereNotNull('email_verified_at');
    }
}
```

### Custom Query Builders
For complex queries, create dedicated query builder classes:

```php
class InvoiceQueryBuilder extends Builder
{
    public function wherePaid(): self
    {
        return $this->whereState('status', InvoiceStatus::PAID);
    }
    
    public function whereOverdue(): self
    {
        return $this->where('due_date', '<', now())
            ->whereNotIn('status', [InvoiceStatus::PAID, InvoiceStatus::CANCELLED]);
    }
}

// Link to model
class Invoice extends Model
{
    public function newEloquentBuilder($query): InvoiceQueryBuilder
    {
        return new InvoiceQueryBuilder($query);
    }
}
```

## Testing Standards

### Framework
All tests use **Pest PHP** with `RefreshDatabase` trait:

```php
<?php

uses(RefreshDatabase::class);

it('creates a user successfully', function () {
    $userData = [
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'password' => 'password123'
    ];
    
    $user = (new CreateUserAction())->execute($userData);
    
    expect($user)->toBeInstanceOf(User::class)
        ->and($user->email)->toBe('john@example.com');
});
```

### Factory Usage
Create factories with realistic, meaningful data:

```php
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => $this->faker->name(),
            'email' => $this->faker->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => bcrypt('password'),
        ];
    }
    
    public function unverified(): static
    {
        return $this->state(['email_verified_at' => null]);
    }
}
```

## Data Processing & Collections

### Custom Collections
Extend Laravel's Collection for complex data processing:

```php
class OrderCollection extends Collection
{
    public function totalValue(): float
    {
        return $this->sum('total_amount');
    }
    
    public function byStatus(OrderStatus $status): static
    {
        return $this->filter(fn (Order $order) => $order->status === $status);
    }
    
    public function shipped(): static
    {
        return $this->byStatus(OrderStatus::SHIPPED);
    }
}

// Model integration
class Order extends Model
{
    public function newCollection(array $models = []): OrderCollection
    {
        return new OrderCollection($models);
    }
}
```

## File Organization Rules

### Directory Structure (Flexible)

**Small Projects:**
```
app/
├── Actions/
├── ViewModels/
├── Models/
└── Services/
```

**Large Projects:**
```
app/
├── Domain/
│   ├── User/
│   │   ├── Actions/
│   │   ├── ViewModels/
│   │   └── Models/
│   └── Order/
└── Shared/
```

## Key Architectural Decisions

1. **Actions over Fat Controllers**: Business logic lives in Actions
2. **View Models for Data Preparation**: Dedicated classes for view data
3. **Domain Organization**: Group related functionality together
4. **DRY Principle**: Eliminate duplication through abstraction
5. **Enum-Driven Types**: Use enums for type safety
6. **Rich Models**: Models contain domain-specific query methods
7. **Thin Controllers**: Handle only HTTP concerns, delegate to Actions

## When Adding New Features

1. **Identify the Domain** - Which business area does this belong to?
2. **Create an Action** - Wrap complex operations in Action classes
3. **Consider View Models** - For reusable view data preparation
4. **Check for DRY Violations** - Can you reuse existing code?
5. **Use Enums** - Replace magic strings with type-safe enums
6. **Keep Controllers Thin** - Delegate to Actions/ViewModels
7. **Domain Boundaries** - Minimize dependencies between domains