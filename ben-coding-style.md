# Ben's Laravel Code Style Guide

This document describes architectural patterns and conventions for Laravel applications. Follow these principles to maintain consistency across projects and ensure clean, maintainable code.

## Core Architectural Principles

### 1. Action Pattern (Primary Pattern)
Actions are single-purpose classes that encapsulate business logic operations.

**Structure:**
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
- **Single responsibility principle** - Each Action has ONE specific purpose
- Use dependency injection in constructor
- Main method is always `execute()`
- Return meaningful data when needed
- Actions orchestrate between services/models

**Single Responsibility Examples:**

```php
// ❌ Bad - Action doing multiple unrelated tasks
class ProcessUserAction
{
    public function execute(User $user): void
    {
        // Data retrieval
        $userData = $this->database->getUserData($user->id);
        
        // Data processing 
        $processedData = $this->processData($userData);
        
        // Cleanup operations
        $this->cleanupOldFiles($user);
        $this->clearUserCache($user);
        
        // Email notification
        $this->sendNotification($user);
    }
}

// ✅ Good - Separate Actions for each responsibility
class RetrieveUserDataAction
{
    public function execute(User $user): array
    {
        return $this->database->getUserData($user->id);
    }
}

class ProcessUserDataAction  
{
    public function execute(array $userData): array
    {
        return $this->processData($userData);
    }
}

class CleanupUserFilesAction
{
    public function execute(User $user): void
    {
        $this->cleanupOldFiles($user);
        $this->clearUserCache($user);
    }
}

class SendUserNotificationAction
{
    public function execute(User $user): void
    {
        $this->sendNotification($user);
    }
}
```

**Why Single Responsibility Matters:**
- **Testability**: Each Action can be tested in isolation
- **Reusability**: Individual Actions can be reused in different contexts
- **Maintainability**: Changes to one responsibility don't affect others
- **Debugging**: Easier to identify and fix issues in focused code
- **Composability**: Multiple Actions can be orchestrated together when needed

### 2. Domain-Driven Organization (DDD)
Organize related functionality into domain-specific folders within the app directory.

**Domain Structure:**
```
app/
├── Actions/
├── Domain/
│   ├── User/
│   │   ├── Models/
│   │   ├── Services/  
│   │   ├── Actions/
│   │   └── Enums/
│   ├── Order/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Actions/
│   └── Product/
│       ├── Models/
│       └── Services/
├── Http/Controllers/
├── Console/Commands/
└── Shared/
    ├── Services/
    └── Enums/
```

**Domain Rules:**
- Group related models, services, actions by business domain
- Cross-domain dependencies should be minimal
- Shared utilities go in `Shared/`
- Each domain is self-contained where possible

### 3. DRY Principle (Don't Repeat Yourself)
Avoid code duplication through strategic abstraction and reuse.

**Common DRY Patterns:**
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

// Helper methods in models
class User extends Model
{
    use HasStatus;
    
    // Avoid duplicating query logic
    public function scopeVerified($query)
    {
        return $query->whereNotNull('email_verified_at');
    }
}
```

### 4. Console Commands as Thin Orchestrators
Commands should delegate to Actions rather than contain business logic.

```php
class ProcessOrdersCommand extends Command
{
    public function handle(ProcessOrdersAction $action): void
    {
        $this->info('Processing orders...');
        
        $result = $action->execute();
        
        $this->info("Processed {$result->count()} orders");
    }
}
```

## Code Style Conventions

### Variable and Parameter Naming
Always use descriptive, unambiguous variable and parameter names:

```php
// ❌ Bad - Abbreviated parameter names
public function handle(SyncFeiertageAction $action): int
{
    return $action->execute();
}

// ✅ Good - Descriptive parameter names
public function handle(SyncFeiertageAction $syncFeiertageAction): int
{
    return $syncFeiertageAction->execute();
}

// ❌ Bad - Generic variable names  
$data = $request->validated();
$result = $service->process($data);

// ✅ Good - Descriptive variable names
$validatedUserData = $request->validated();
$userCreationResult = $service->process($validatedUserData);
```

**Key Rules:**
- Parameter names should match or expand on the type name
- Avoid abbreviations unless they're universally understood
- Use complete words that clearly describe the variable's purpose
- Method parameters should be self-documenting

### Eloquent Query Methods
Always prefix Eloquent methods like `updateOrCreate`, `firstOrCreate`, etc. with `query()` for better IDE autocompletion:

```php
// ❌ Bad - Missing query() prefix
$user = User::updateOrCreate(
    ['email' => $email],
    ['name' => $name, 'status' => 'active']
);

$product = Product::firstOrCreate(['sku' => $sku]);

// ✅ Good - Using query() prefix
$user = User::query()->updateOrCreate(
    ['email' => $email],
    ['name' => $name, 'status' => 'active']
);

$product = Product::query()->firstOrCreate(['sku' => $sku]);
```

**Benefits:**
- Better IDE autocompletion and type hints
- Explicit query builder usage
- Consistent with complex query chains
- Easier to extend with additional where clauses

### Collection Usage Patterns
Prefer Laravel collections and functional programming:

```php
$results = $users
    ->filter(fn (User $user): bool => $user->isActive())
    ->map(fn (User $user): array => $user->toSummary())
    ->groupBy('department')
    ->sortKeys();
```

### Enum-Driven Configuration
Use enums for type safety and central configuration instead of arrays or constants:

```php
enum OrderStatus: string
{
    case PENDING = 'pending';
    case CONFIRMED = 'confirmed';
    case SHIPPED = 'shipped';
    case DELIVERED = 'delivered';
    
    public function getLabel(): string
    {
        return match ($this) {
            self::PENDING => 'Pending Payment',
            self::CONFIRMED => 'Order Confirmed', 
            self::SHIPPED => 'Shipped',
            self::DELIVERED => 'Delivered',
        };
    }
    
    public function canTransitionTo(OrderStatus $status): bool
    {
        return match ($this) {
            self::PENDING => $status === self::CONFIRMED,
            self::CONFIRMED => $status === self::SHIPPED,
            self::SHIPPED => $status === self::DELIVERED,
            self::DELIVERED => false,
        };
    }
}

// ❌ NEVER do this - Arrays for static data are bad
private array $germanStates = [
    'BW' => 'Baden-Württemberg',
    'BY' => 'Bayern',
    'BE' => 'Berlin',
    // ...
];

// ✅ ALWAYS use enums instead
enum GermanState: string
{
    case BADEN_WUERTTEMBERG = 'BW';
    case BAYERN = 'BY';
    case BERLIN = 'BE';
    case BRANDENBURG = 'BB';
    case BREMEN = 'HB';
    case HAMBURG = 'HH';
    case HESSEN = 'HE';
    case MECKLENBURG_VORPOMMERN = 'MV';
    case NIEDERSACHSEN = 'NI';
    case NORDRHEIN_WESTFALEN = 'NW';
    case RHEINLAND_PFALZ = 'RP';
    case SAARLAND = 'SL';
    case SACHSEN = 'SN';
    case SACHSEN_ANHALT = 'ST';
    case SCHLESWIG_HOLSTEIN = 'SH';
    case THUERINGEN = 'TH';
    case NATIONAL = 'NATIONAL';
    
    public function getLabel(): string
    {
        return match ($this) {
            self::BADEN_WUERTTEMBERG => 'Baden-Württemberg',
            self::BAYERN => 'Bayern',
            self::BERLIN => 'Berlin',
            self::BRANDENBURG => 'Brandenburg',
            self::BREMEN => 'Bremen',
            self::HAMBURG => 'Hamburg',
            self::HESSEN => 'Hessen',
            self::MECKLENBURG_VORPOMMERN => 'Mecklenburg-Vorpommern',
            self::NIEDERSACHSEN => 'Niedersachsen',
            self::NORDRHEIN_WESTFALEN => 'Nordrhein-Westfalen',
            self::RHEINLAND_PFALZ => 'Rheinland-Pfalz',
            self::SAARLAND => 'Saarland',
            self::SACHSEN => 'Sachsen',
            self::SACHSEN_ANHALT => 'Sachsen-Anhalt',
            self::SCHLESWIG_HOLSTEIN => 'Schleswig-Holstein',
            self::THUERINGEN => 'Thüringen',
            self::NATIONAL => 'National',
        };
    }
}
```

### Service Classes
Services contain focused business logic that doesn't fit in Actions:

```php
class PaymentService
{
    public function processPayment(Order $order, array $paymentData): PaymentResult
    {
        // Focused payment processing logic
    }
    
    public function refund(Payment $payment): RefundResult  
    {
        // Focused refund logic
    }
}
```

## Database & Model Patterns

### Rich Relationship Methods
Create descriptive methods for common relationship queries:

```php
class User extends Model 
{
    public function activeOrders(): HasMany
    {
        return $this->orders()->where('status', '!=', OrderStatus::CANCELLED);
    }
    
    public function recentOrders(): HasMany
    {
        return $this->orders()->where('created_at', '>=', now()->subDays(30));
    }
}
```

### Pivot Tables with Additional Data
When many-to-many relationships need extra data:

```php
public function products(): BelongsToMany
{
    return $this->belongsToMany(Product::class)
        ->withPivot(['quantity', 'price', 'notes'])
        ->withTimestamps();
}
```

## File Organization Rules

### Directory Structure (Flexible)
Choose the structure that fits your project size:

**Small Projects:**
```
app/
├── Actions/
├── Models/
├── Services/
├── Enums/
└── Http/Controllers/
```

**Medium Projects:**
```
app/
├── Actions/
├── Domain/
│   ├── User/
│   ├── Order/
│   └── Product/
├── Shared/
└── Http/
```

**Large Projects:**
```
app/
├── Domain/
│   ├── User/
│   │   ├── Actions/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Http/Controllers/
│   └── Order/
│       └── [same structure]
└── Shared/
```

## Key Architectural Decisions

1. **Actions over Fat Controllers**: Business logic lives in Actions
2. **Domain Organization**: Group related functionality together
3. **DRY Principle**: Eliminate duplication through abstraction
4. **Enum-Driven Types**: Use enums for type safety and configuration
5. **Service Classes**: Focused services for specific business areas
6. **Rich Models**: Models contain domain-specific query methods

## When Adding New Features

1. **Identify the Domain** - Which business area does this belong to?
2. **Create an Action** - Wrap complex operations in Action classes
3. **Check for DRY Violations** - Can you reuse existing code?
4. **Use Enums** - Replace magic strings/numbers with type-safe enums
5. **Keep Controllers Thin** - Controllers should only handle HTTP concerns
6. **Domain Boundaries** - Minimize dependencies between domains

## Error Handling & Logging

Keep error handling proportional to the application's needs:

```php
// Simple applications
public function execute(): User
{
    return $this->userService->create($data);
}

// Complex applications (when needed)
public function execute(): User  
{
    try {
        return $this->userService->create($data);
    } catch (ValidationException $e) {
        Log::warning('User creation failed', ['errors' => $e->errors()]);
        throw $e;
    }
}
```

Only add extensive logging and error handling when the application complexity demands it.

## Testing Standards

### Testing Framework
All tests must use **Pest PHP** testing framework instead of PHPUnit.

### Database Testing
- All tests should refresh the database using `RefreshDatabase` trait
- Use transactions for test isolation where appropriate

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
Always create factories for models with realistic, meaningful data:

```php
<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => $this->faker->name(),
            'email' => $this->faker->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => bcrypt('password'),
            'phone' => $this->faker->phoneNumber(),
            'address' => $this->faker->streetAddress(),
            'city' => $this->faker->city(),
            'postal_code' => $this->faker->postcode(),
            'country' => $this->faker->country(),
        ];
    }
    
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
```

**Factory Rules:**
- Use realistic data that represents actual use cases
- Provide state methods for common variations
- Include all relevant fields, not just required ones
- Use appropriate faker methods for each field type

## Data Processing & Collections

### Custom Collections
When working with complex data processing, create custom collections that extend Laravel's base Collection:

```php
<?php

namespace App\Collections;

use Illuminate\Support\Collection;

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
    
    public function groupByMonth(): Collection
    {
        return $this->groupBy(fn (Order $order) => $order->created_at->format('Y-m'));
    }
}
```

**Custom Collection Rules:**
- Extend `Illuminate\Support\Collection`
- Add domain-specific methods that enhance readability
- Use when data processing becomes complex or repetitive
- Return appropriate types (`static` for chainable methods, specific types for terminal operations)
- Prefer descriptive method names over generic operations

**Model Integration:**
```php
class Order extends Model
{
    public function newCollection(array $models = []): OrderCollection
    {
        return new OrderCollection($models);
    }
}

// Usage in queries
$orders = Order::query()->where('status', OrderStatus::PENDING)->get();
// $orders is now an OrderCollection instance with custom methods
$shippedOrders = $orders->shipped();
$totalValue = $orders->totalValue();
```

This style guide emphasizes maintainability, domain organization, and the DRY principle while staying flexible enough to adapt to different project sizes and requirements.