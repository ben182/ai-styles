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

### 2. View Model Pattern
View models are classes that prepare and provide data specifically for views, keeping controllers thin and promoting reusability.

**Core Concept:**
View models encapsulate all logic for preparing view data, avoiding duplication across controllers and maintaining separation of concerns.

**Basic Structure:**
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
    
    public function tags(): Collection
    {
        return Tag::query()
            ->active()
            ->orderBy('name')
            ->get();
    }
}
```

**Controller Integration:**
```php
class PostsController extends Controller
{
    public function create()
    {
        $viewModel = new PostFormViewModel(
            current_user()
        );
        
        return view('blog.form', compact('viewModel'));
    }
    
    public function edit(Post $post)
    {
        $viewModel = new PostFormViewModel(
            current_user(),
            $post
        );
        
        return view('blog.form', compact('viewModel'));
    }
}
```

**Blade View Usage:**
```blade
<form>
    <input value="{{ $viewModel->post()->title }}" />
    <textarea>{{ $viewModel->post()->body }}</textarea>
    
    <select name="category_id">
        @foreach($viewModel->categories() as $category)
            <option value="{{ $category->id }}"
                @selected($viewModel->post()->category_id === $category->id)>
                {{ $category->name }}
            </option>
        @endforeach
    </select>
    
    <div class="tags">
        @foreach($viewModel->tags() as $tag)
            <label>
                <input type="checkbox" name="tags[]" value="{{ $tag->id }}"
                    @checked($viewModel->post()->tags->contains($tag->id))>
                {{ $tag->name }}
            </label>
        @endforeach
    </div>
</form>
```

**Laravel Integration Features:**

*Arrayable Implementation:*
```php
use Illuminate\Contracts\Support\Arrayable;

class PostFormViewModel implements Arrayable
{
    // ... existing methods
    
    public function toArray(): array
    {
        return [
            'post' => $this->post(),
            'categories' => $this->categories(),
            'tags' => $this->tags(),
        ];
    }
}

// Controller can now pass view model directly
return view('blog.form', $viewModel);

// Blade can use properties directly
<input value="{{ $post->title }}" />
```

*Responsable Implementation:*
```php
use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\JsonResponse;

class PostFormViewModel implements Responsable
{
    // ... existing methods
    
    public function toResponse($request): JsonResponse
    {
        return response()->json([
            'post' => PostResource::make($this->post()),
            'categories' => CategoryResource::collection($this->categories()),
            'tags' => TagResource::collection($this->tags()),
        ]);
    }
}

// Useful for AJAX form updates
public function update(Request $request, Post $post): PostFormViewModel
{
    // Update the post...
    
    return new PostFormViewModel(
        current_user(),
        $post,
    );
}
```

**Combined with Resources:**
```php
class PostViewModel implements Arrayable, Responsable
{
    public function __construct(
        private Post $post,
        private User $currentUser
    ) {}
    
    public function values(): array
    {
        return PostResource::make($this->post)->resolve();
    }
    
    public function canEdit(): bool
    {
        return $this->currentUser->can('update', $this->post);
    }
    
    public function relatedPosts(): Collection
    {
        return Post::query()
            ->where('category_id', $this->post->category_id)
            ->where('id', '!=', $this->post->id)
            ->published()
            ->limit(5)
            ->get();
    }
}
```

**Key Benefits:**
- **Reusability**: Same view model works for create/edit/show contexts
- **Separation of Concerns**: View logic separated from business logic
- **Testability**: View models can be unit tested independently
- **DRY Principle**: Eliminates duplication across controllers
- **Flexibility**: Easy to modify view requirements without touching controllers

**View Model Rules:**
- Place in `app/ViewModels/` directory
- Use dependency injection in constructor for all dependencies
- Methods should return data ready for view consumption
- Implement `Arrayable` for direct view passing
- Implement `Responsable` for AJAX responses when needed
- Combine with Resources for complex data transformation
- Keep view models focused on single view or view family

### 3. Domain-Driven Organization (DDD)
Organize related functionality into domain-specific folders within the app directory.

**Domain Structure:**
```
app/
├── Actions/
├── ViewModels/
├── Domain/
│   ├── User/
│   │   ├── Models/
│   │   ├── Services/  
│   │   ├── Actions/
│   │   ├── ViewModels/
│   │   └── Enums/
│   ├── Order/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Actions/
│   │   └── ViewModels/
│   └── Product/
│       ├── Models/
│       ├── Services/
│       └── ViewModels/
├── Http/Controllers/
├── Console/Commands/
└── Shared/
    ├── Services/
    ├── ViewModels/
    └── Enums/
```

**Domain Rules:**
- Group related models, services, actions by business domain
- Cross-domain dependencies should be minimal
- Shared utilities go in `Shared/`
- Each domain is self-contained where possible

### 4. DRY Principle (Don't Repeat Yourself)
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

### 5. Console Commands as Thin Orchestrators
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

### Models ≠ Business Logic
Models should focus on data representation and access, not business logic. Laravel provides extensive Eloquent functionality for data operations, but resist adding complex business logic directly to models.

**What NOT to do:**
```php
// ❌ Bad - Business logic in model
class Invoice extends Model
{
    public function getTotalPriceAttribute(): int
    {
        return $this->invoiceLines
            ->reduce(
                fn (int $totalPrice, InvoiceLine $invoiceLine) => 
                    $totalPrice + $invoiceLine->total_price,
                0
            );
    }
}

class InvoiceLine extends Model
{
    public function getTotalPriceAttribute(): int
    {
        $vatCalculator = app(VatCalculator::class);
        $price = $this->item_amount * $this->item_price;
        
        if ($this->price_excluding_vat) {
            $price = $vatCalculator->totalPrice(
                $price,
                $this->vat_percentage,
            );
        }
        
        return $price;
    }
}
```

**What TO do:**
```php
// ✅ Good - Business logic in Actions, models store calculated data
class CalculateInvoiceTotalAction
{
    public function __construct(
        private VatCalculator $vatCalculator
    ) {}
    
    public function execute(Invoice $invoice): int
    {
        $totalPrice = $invoice->invoiceLines
            ->sum(fn (InvoiceLine $line) => $this->calculateLineTotal($line));
            
        // Store the calculated result
        $invoice->update(['total_price' => $totalPrice]);
        
        return $totalPrice;
    }
    
    private function calculateLineTotal(InvoiceLine $line): int
    {
        $price = $line->item_amount * $line->item_price;
        
        if ($line->price_excluding_vat) {
            $price = $this->vatCalculator->totalPrice(
                $price,
                $line->vat_percentage,
            );
        }
        
        return $price;
    }
}

// Model simply provides access to stored data
class Invoice extends Model
{
    public function total_price(): int
    {
        return $this->total_price; // Pre-calculated by Action
    }
}
```

**Benefits of separating business logic:**
- **Performance**: Calculations performed once, not on every access
- **Queryability**: Can query calculated data directly in database
- **Maintainability**: Business logic changes don't affect model structure
- **Testability**: Business logic can be tested independently

### Scaling Down Models
Keep models focused on data access by moving other responsibilities to dedicated classes.

**Query Builder Classes:**
Instead of adding many query scopes to models, create dedicated query builder classes:

```php
// ✅ Custom Query Builder
namespace App\Domain\Invoices\QueryBuilders;

use App\Domain\Invoices\Enums\InvoiceStatus;
use Illuminate\Database\Eloquent\Builder;

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
    
    public function forDateRange(Carbon $startDate, Carbon $endDate): self
    {
        return $this->whereBetween('created_at', [$startDate, $endDate]);
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

// Usage
$paidInvoices = Invoice::query()->wherePaid()->get();
$overdueInvoices = Invoice::query()->whereOverdue()->get();
```

**Custom Collection Classes:**
Move complex collection operations to dedicated collection classes:

```php
// ✅ Custom Collection
namespace App\Domain\Invoices\Collections;

use Illuminate\Database\Eloquent\Collection;

class InvoiceLineCollection extends Collection
{
    public function creditLines(): self
    {
        return $this->filter(fn (InvoiceLine $invoiceLine) => 
            $invoiceLine->isCreditLine()
        );
    }
    
    public function totalAmount(): int
    {
        return $this->sum('total_price');
    }
    
    public function groupByVatRate(): Collection
    {
        return $this->groupBy('vat_percentage');
    }
}

// Link to model
class InvoiceLine extends Model
{
    public function newCollection(array $models = []): InvoiceLineCollection
    {
        return new InvoiceLineCollection($models);
    }
    
    public function isCreditLine(): bool
    {
        return $this->price < 0.0;
    }
}

// Usage
$invoice
    ->invoiceLines
    ->creditLines()
    ->map(function (InvoiceLine $invoiceLine) {
        // ...
    });
```

### Event-Driven Models
For complex business workflows, use dedicated event classes instead of generic model events:

```php
// ✅ Specific Event Classes
class InvoiceSavingEvent
{
    public function __construct(
        public Invoice $invoice
    ) {}
}

class InvoiceDeletingEvent
{
    public function __construct(
        public Invoice $invoice
    ) {}
}

// Model configuration
class Invoice extends Model
{
    protected $dispatchesEvents = [
        'saving' => InvoiceSavingEvent::class,
        'deleting' => InvoiceDeletingEvent::class,
    ];
}

// Dedicated Event Subscriber
class InvoiceSubscriber
{
    public function __construct(
        private CalculateInvoiceTotalAction $calculateTotalAction
    ) {}

    public function saving(InvoiceSavingEvent $event): void
    {
        $invoice = $event->invoice;
        
        // Business logic handled by Action
        $invoice->total_price = $this->calculateTotalAction->execute($invoice);
    }

    public function subscribe(Dispatcher $dispatcher): void
    {
        $dispatcher->listen(
            InvoiceSavingEvent::class,
            self::class . '@saving'
        );
    }
}

// Register in EventServiceProvider
class EventServiceProvider extends ServiceProvider
{
    protected $subscribe = [
        InvoiceSubscriber::class,
    ];
}
```

### Rich Model Data Access
Models should provide rich data access methods while avoiding heavy business logic:

```php
class User extends Model 
{
    // ✅ Good - Rich relationship methods
    public function activeOrders(): HasMany
    {
        return $this->orders()->where('status', '!=', OrderStatus::CANCELLED);
    }
    
    public function recentOrders(): HasMany
    {
        return $this->orders()->where('created_at', '>=', now()->subDays(30));
    }
    
    // ✅ Good - Simple accessors for presentation
    public function getFullNameAttribute(): string
    {
        return "{$this->first_name} {$this->last_name}";
    }
    
    // ✅ Good - Simple query scopes
    public function scopeVerified($query)
    {
        return $query->whereNotNull('email_verified_at');
    }
    
    // ✅ Good - Data validation/formatting
    public function setEmailAttribute($value): void
    {
        $this->attributes['email'] = strtolower(trim($value));
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

### Model Architecture Guidelines

**What models SHOULD contain:**
- Database schema representation (fillable, casts, etc.)
- Simple accessors and mutators for data formatting
- Relationship definitions
- Simple query scopes for data access
- Data validation rules (when using model validation)

**What models should NOT contain:**
- Complex business logic calculations
- External service integrations
- Complex query building (use Query Builders)
- Email sending or external API calls
- File processing or heavy computations

**Model Organization:**
```php
class Order extends Model
{
    // 1. Model configuration
    protected $fillable = ['user_id', 'status', 'total_amount'];
    protected $casts = ['status' => OrderStatus::class];
    
    // 2. Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
    
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }
    
    // 3. Query scopes (simple ones)
    public function scopePending($query)
    {
        return $query->where('status', OrderStatus::PENDING);
    }
    
    // 4. Accessors/Mutators (simple formatting only)
    public function getFormattedTotalAttribute(): string
    {
        return number_format($this->total_amount / 100, 2);
    }
    
    // 5. Custom query builder/collection (when needed)
    public function newEloquentBuilder($query): OrderQueryBuilder
    {
        return new OrderQueryBuilder($query);
    }
}
```

This approach maintains the power of Laravel's Eloquent while keeping models focused, maintainable, and performant. Business logic lives in Actions, complex queries in Query Builders, and collection operations in Custom Collections.

## File Organization Rules

### Directory Structure (Flexible)
Choose the structure that fits your project size:

**Small Projects:**
```
app/
├── Actions/
├── ViewModels/
├── Models/
├── Services/
├── Enums/
└── Http/Controllers/
```

**Medium Projects:**
```
app/
├── Actions/
├── ViewModels/
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
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Http/Controllers/
│   └── Order/
│       └── [same structure]
└── Shared/
    └── ViewModels/
```

## Key Architectural Decisions

1. **Actions over Fat Controllers**: Business logic lives in Actions
2. **View Models for Data Preparation**: Dedicated classes for view data preparation and reusability
3. **Domain Organization**: Group related functionality together
4. **DRY Principle**: Eliminate duplication through abstraction
5. **Enum-Driven Types**: Use enums for type safety and configuration
6. **Service Classes**: Focused services for specific business areas
7. **Rich Models**: Models contain domain-specific query methods

## When Adding New Features

1. **Identify the Domain** - Which business area does this belong to?
2. **Create an Action** - Wrap complex operations in Action classes
3. **Consider View Models** - For views that need data preparation or will be reused across controllers
4. **Check for DRY Violations** - Can you reuse existing code?
5. **Use Enums** - Replace magic strings/numbers with type-safe enums
6. **Keep Controllers Thin** - Controllers should only handle HTTP concerns and delegate to Actions/ViewModels
7. **Domain Boundaries** - Minimize dependencies between domains

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