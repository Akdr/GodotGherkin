# GodotGherkin

A Behavior-Driven Development (BDD) testing framework for Godot 4.3+ that enables writing tests in Gherkin syntax with GDScript step definitions.

## Features

- **Gherkin Syntax Support**: Write tests in natural language using Feature, Scenario, Given/When/Then
- **Headless-First Design**: Built for CI/CD pipelines and AI assistant integration
- **Async Step Support**: Steps can use `await` for timing-sensitive operations
- **Multiple Output Formats**: Console (human-readable) and JSON (machine-readable)
- **Cucumber Expressions**: Pattern matching with `{int}`, `{float}`, `{string}`, `{word}` placeholders
- **Scenario Outlines**: Data-driven testing with Examples tables
- **Tag Filtering**: Run specific scenarios using `@tags`

## Installation

### Option 1: Git Submodule (Recommended)

```bash
# Add as submodule
git submodule add https://github.com/Akdr/GodotGherkin.git addons/godot_gherkin

# For existing clones with submodules
git submodule update --init --recursive

# Update to latest version
git submodule update --remote addons/godot_gherkin
```

### Option 2: Manual Copy

1. Download or clone this repository
2. Copy the `addons/godot_gherkin` folder to your project's `addons/` directory

### Enable Plugin (Optional)

Enable the plugin in Project Settings > Plugins for editor integration.

## Quick Start

### 1. Create a Feature File

Create `tests/features/inventory.feature`:

```gherkin
@inventory
Feature: Inventory Management
  As a player
  I want to manage my inventory
  So that I can collect and use items

  Background:
    Given the player has no items

  Scenario: Picking up items
    When I pick up 5 apples
    Then I should have 5 items

  Scenario: Dropping items
    Given I have 10 items in my inventory
    When I drop "sword"
    Then I should have 9 items
```

### 2. Create Step Definitions

Create `tests/steps/inventory_steps.gd`:

```gdscript
extends RefCounted

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
    registry.given("the player has no items", _no_items)
    registry.given("I have {int} items in my inventory", _have_items)
    registry.when("I pick up {int} {word}(s)", _pick_up)
    registry.when("I drop {string}", _drop)
    registry.then("I should have {int} items", _should_have)


func _no_items(ctx: TestContextScript) -> void:
    ctx.set_value("inventory_count", 0)


func _have_items(ctx: TestContextScript, count: int) -> void:
    ctx.set_value("inventory_count", count)


func _pick_up(ctx: TestContextScript, count: int, item_type: String) -> void:
    var current: int = ctx.get_value("inventory_count", 0)
    ctx.set_value("inventory_count", current + count)


func _drop(ctx: TestContextScript, item_name: String) -> void:
    var current: int = ctx.get_value("inventory_count", 0)
    ctx.set_value("inventory_count", current - 1)


func _should_have(ctx: TestContextScript, expected: int) -> void:
    var actual: int = ctx.get_value("inventory_count", 0)
    ctx.assert_equal(actual, expected)
```

### 3. Create Test Runner

Create `tests/run_tests.gd`:

```gdscript
#!/usr/bin/env -S godot --headless --script
extends SceneTree

const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")


func _init() -> void:
    var cli := GherkinCLIScript.new(self)
    var exit_code := await cli.run(OS.get_cmdline_user_args())
    quit(exit_code)
```

### 4. Run Tests

```bash
# Run all tests
godot --headless --script tests/run_tests.gd

# Run with verbose output
godot --headless --script tests/run_tests.gd -- --verbose

# Run specific feature
godot --headless --script tests/run_tests.gd -- --feature tests/features/inventory.feature

# Run with tag filter
godot --headless --script tests/run_tests.gd -- --tags @inventory

# JSON output (for CI/AI tools)
godot --headless --script tests/run_tests.gd -- --format json
```

## CLI Options

| Option | Description |
|--------|-------------|
| `--feature, -f <path>` | Run a specific feature file |
| `--features <path>` | Path to features directory (default: `res://tests/features`) |
| `--steps <path>` | Path to steps directory (default: `res://tests/steps`) |
| `--tags, -t <tag>` | Filter by tag (use `~@tag` to exclude) |
| `--format <type>` | Output format: `console` (default), `json` |
| `--output, -o <path>` | Write output to file |
| `--verbose, -v` | Show step details and timing |
| `--dry-run` | List scenarios without executing |
| `--fail-fast` | Stop on first failure |
| `--no-color` | Disable colored output |
| `--help, -h` | Show help message |

## Gherkin Syntax Reference

### Keywords

- **Feature**: Describes a feature being tested
- **Background**: Steps run before each scenario
- **Scenario**: A single test case
- **Scenario Outline**: Parameterized scenario with Examples
- **Given**: Preconditions (setup)
- **When**: Actions (the thing being tested)
- **Then**: Expected outcomes (assertions)
- **And/But**: Continue previous Given/When/Then (inherits keyword context)
- **Examples**: Data table for Scenario Outline

### Tags

Tags start with `@` and can be used for filtering:

```gherkin
@smoke @critical
Feature: Login

  @slow
  Scenario: Complex login flow
    ...
```

Run with: `--tags @smoke --tags ~@slow` (include @smoke, exclude @slow)

### Data Tables

```gherkin
Scenario: Create users
  Given the following users exist:
    | name  | email           | role  |
    | Alice | alice@test.com  | admin |
    | Bob   | bob@test.com    | user  |
```

### Doc Strings

```gherkin
Scenario: API response
  Then the response should be:
    """json
    {
      "status": "success",
      "count": 42
    }
    """
```

### Scenario Outline

```gherkin
Scenario Outline: Multiple calculations
  Given the calculator shows <initial>
  When I add <addend>
  Then the result should be <result>

  Examples:
    | initial | addend | result |
    | 0       | 5      | 5      |
    | 10      | 3      | 13     |
```

## Parameter Types

| Type | Pattern | Example |
|------|---------|---------|
| `{int}` | `-?\\d+` | `42`, `-7` |
| `{float}` | `-?\\d*\\.?\\d+` | `3.14`, `-0.5` |
| `{word}` | `\\S+` | `apple`, `test123` |
| `{string}` | `"..."` or `'...'` | `"hello"`, `'world'` |
| `{any}` | `.*` | anything |

### Optional Text

Use parentheses for optional text:

```gdscript
registry.when("I have {int} apple(s)", _have_apples)
# Matches: "I have 1 apple" and "I have 5 apples"
```

### Alternation

Use `/` for alternatives:

```gdscript
registry.when("I click/press the button", _click_button)
# Matches: "I click the button" and "I press the button"
```

### Multi-Keyword Steps with `registry.step()`

When a step can appear with different keywords (Given/When/Then/And), use `registry.step()`:

```gdscript
# PROBLEM: "And I navigate to X" won't match when And follows Given
# because And inherits Given's context, not When's
registry.when("I navigate to {string}", _navigate)

# SOLUTION: Use registry.step() to match any keyword
registry.step("I navigate to {string}", _navigate)
```

This is especially important for steps that might appear as:
- `When I navigate to "home"`
- `And I navigate to "settings"` (after a Given step)

## TestContext API

The `TestContext` is passed to every step function and provides:

### State Management

```gdscript
ctx.set_value("key", value)        # Store a value
ctx.get_value("key", default)      # Retrieve a value
ctx.has_value("key")               # Check if key exists
ctx.remove_value("key")            # Remove a value
```

### Assertions

```gdscript
ctx.assert_equal(actual, expected, message)
ctx.assert_not_equal(actual, not_expected, message)
ctx.assert_true(condition, message)
ctx.assert_false(condition, message)
ctx.assert_null(value, message)
ctx.assert_not_null(value, message)
ctx.assert_contains(container, item, message)
ctx.assert_not_contains(container, item, message)
ctx.assert_greater(actual, threshold, message)
ctx.assert_less(actual, threshold, message)
ctx.fail(message)
```

### Scene Management

```gdscript
ctx.load_scene("res://scenes/game.tscn")  # Load and instantiate
ctx.get_scene()                            # Get current scene
ctx.get_node("Player")                     # Get node from scene
ctx.free_scene()                           # Clean up scene
```

## Async Steps

Steps can use `await` for asynchronous operations:

```gdscript
func register_steps(registry: StepRegistryScript) -> void:
    registry.when("I wait for {float} seconds", _wait)
    registry.when("the animation completes", _wait_animation)


func _wait(ctx: TestContextScript, seconds: float) -> void:
    await ctx.get_tree().create_timer(seconds).timeout


func _wait_animation(ctx: TestContextScript) -> void:
    var player: AnimationPlayer = ctx.get_node("AnimationPlayer")
    await player.animation_finished
```

## Testing Patterns

### Mock Pattern for Autoload-Dependent Systems

Systems that reference autoloads (like EventBus, GameManager) cannot compile in headless mode without those autoloads present. Use mock objects to test the behavior pattern:

```gdscript
# Instead of testing SubSceneManager directly (which references EventBus),
# mock the state management pattern:

func _given_at_location(ctx: TestContextScript, location: String) -> void:
    # Mock the navigation state instead of using real autoload
    ctx.set_value("current_location", location)
    ctx.set_value("history", [location])


func _when_navigate_to(ctx: TestContextScript, destination: String) -> void:
    var history: Array = ctx.get_value("history", [])
    history.append(destination)
    ctx.set_value("history", history)
    ctx.set_value("current_location", destination)


func _then_should_be_at(ctx: TestContextScript, expected: String) -> void:
    var current: String = ctx.get_value("current_location", "")
    ctx.assert_equal(current, expected, "Expected to be at %s" % expected)
```

This pattern lets you test navigation logic, state machines, and other behaviors without requiring the full game infrastructure.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | Error (invalid arguments, missing files, etc.) |

## Project Structure

```
your_project/
├── addons/
│   └── godot_gherkin/          # The addon
├── tests/
│   ├── features/               # .feature files
│   │   └── *.feature
│   ├── steps/                  # Step definitions
│   │   └── *_steps.gd
│   └── run_tests.gd            # CLI entry point
└── project.godot
```

## JSON Output Format

When using `--format json`, output is structured for machine parsing:

```json
{
  "success": true,
  "summary": {
    "total_scenarios": 4,
    "passed": 4,
    "failed": 0,
    "skipped": 0,
    "duration_ms": 42
  },
  "features": [
    {
      "name": "Calculator",
      "file": "tests/features/example.feature",
      "scenarios": [
        {
          "name": "Addition",
          "status": "passed",
          "steps": [
            {"keyword": "Given", "text": "the calculator is reset", "status": "passed", "duration_ms": 1}
          ]
        }
      ]
    }
  ],
  "undefined_steps": [],
  "pending_steps": []
}
```

## Requirements

- Godot 4.3+ (tested with 4.3, 4.4, 4.5)
- No external dependencies

## License

See [LICENSE](LICENSE) file.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
