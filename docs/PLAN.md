# GodotGherkin Implementation Plan

## Overview
A Gherkin/BDD parser addon for Godot 4.5+ that enables writing and running behavior-driven tests using `.feature` files and GDScript step definitions.

**Primary Use Case**: Headless CLI execution for AI assistants and automation tools (Claude Code, CI/CD)
**Secondary Use Case**: Editor integration for interactive development

---

## Architecture Principles

### Headless-First Design
1. **No EditorPlugin dependencies in core** - All parsing, execution, and reporting work without Godot editor
2. **CLI runner script** - Executable via `godot --headless --script`
3. **Machine-readable output** - JSON output option for AI/tool parsing
4. **Human-readable output** - Clean console output with ANSI colors (optional)
5. **Exit codes** - 0 for pass, 1 for failures, 2 for errors
6. **Async step support** - Steps can use `await` for timing-sensitive operations
7. **Explicit registration API** - `registry.given/when/then()` pattern for step definitions

### Project Structure
- Includes `project.godot` for immediate testing and development
- Self-contained addon with example tests

---

## Directory Structure

```
project.godot                     # Godot project file (for testing/development)
addons/
  godot_gherkin/
    plugin.cfg                    # Plugin metadata
    plugin.gd                     # EditorPlugin (optional, for editor UI)

    # Core (headless-compatible)
    core/
      gherkin_lexer.gd           # Tokenizer for .feature files
      gherkin_parser.gd          # AST builder from tokens
      gherkin_ast.gd             # AST node definitions

    # Step definitions (headless-compatible)
    steps/
      step_registry.gd           # Global step registration
      step_definition.gd         # Step definition class
      step_matcher.gd            # Pattern matching engine
      parameter_types.gd         # Built-in and custom parameter types

    # Test execution (headless-compatible)
    runner/
      test_runner.gd             # Main test orchestrator
      scenario_executor.gd       # Executes individual scenarios
      test_context.gd            # Shared state between steps
      test_result.gd             # Result data structures
      cli_runner.gd              # CLI entry point (--headless)
      reporters/
        console_reporter.gd      # Human-readable console output
        json_reporter.gd         # Machine-readable JSON output

    # Utilities (headless-compatible)
    util/
      file_scanner.gd            # .feature file discovery

    # Editor integration (optional)
    editor/
      gherkin_dock.gd            # Bottom panel dock UI
      gherkin_dock.tscn          # Dock scene

# Example tests (included in project)
tests/
  features/
    example.feature              # Example feature file
  steps/
    example_steps.gd             # Example step definitions
  run_tests.gd                   # CLI entry script
```

---

## CLI Execution

### Primary Entry Point: `run_tests.gd`

```gdscript
#!/usr/bin/env -S godot --headless --script
extends SceneTree

func _init() -> void:
    var runner := GherkinCLI.new()
    var exit_code := runner.run(OS.get_cmdline_args())
    quit(exit_code)
```

### Usage Examples

```bash
# Run all tests
godot --headless --script tests/run_tests.gd

# Run specific feature
godot --headless --script tests/run_tests.gd -- --feature tests/features/inventory.feature

# Run with tag filter
godot --headless --script tests/run_tests.gd -- --tags @smoke --tags ~@slow

# JSON output for AI parsing
godot --headless --script tests/run_tests.gd -- --format json

# JUnit XML for CI
godot --headless --script tests/run_tests.gd -- --format junit --output results.xml

# Verbose output
godot --headless --script tests/run_tests.gd -- --verbose

# List scenarios without running
godot --headless --script tests/run_tests.gd -- --dry-run
```

### CLI Options

| Option | Description |
|--------|-------------|
| `--feature <path>` | Run specific feature file |
| `--tags <expr>` | Tag filter (e.g., `@smoke`, `~@slow`) |
| `--format <type>` | Output format: `console` (default), `json`, `junit` |
| `--output <path>` | Write output to file |
| `--verbose` | Show step details and timing |
| `--dry-run` | List scenarios without executing |
| `--fail-fast` | Stop on first failure |
| `--no-color` | Disable ANSI colors |

---

## Output Formats

### Console Output (Default)
```
Feature: Inventory Management
  Scenario: Picking up items
    Given the player has no items ✓
    When I pick up 5 apples ✓
    Then I should have 5 items ✓

  Scenario: Dropping items
    Given I have 10 items in my inventory ✓
    When I drop "sword" ✓
    Then I should have 9 items ✗
      Expected 9 but got 10

2 scenarios (1 passed, 1 failed)
6 steps (5 passed, 1 failed)
Finished in 0.042s
```

### JSON Output (for AI/tools)
```json
{
  "success": false,
  "summary": {
    "total_scenarios": 2,
    "passed": 1,
    "failed": 1,
    "duration_ms": 42
  },
  "features": [
    {
      "name": "Inventory Management",
      "file": "tests/features/inventory.feature",
      "scenarios": [
        {
          "name": "Picking up items",
          "status": "passed",
          "steps": [
            {"keyword": "Given", "text": "the player has no items", "status": "passed", "duration_ms": 1}
          ]
        },
        {
          "name": "Dropping items",
          "status": "failed",
          "error": "Expected 9 but got 10",
          "failed_step": {
            "keyword": "Then",
            "text": "I should have 9 items",
            "line": 12
          }
        }
      ]
    }
  ],
  "undefined_steps": [],
  "pending_steps": []
}
```

---

## Core Components

### 1. GherkinLexer (`core/gherkin_lexer.gd`)
Tokenizes `.feature` file text into a token stream.

**Key tokens**: `FEATURE`, `SCENARIO`, `SCENARIO_OUTLINE`, `BACKGROUND`, `GIVEN`, `WHEN`, `THEN`, `AND`, `BUT`, `TAG`, `TABLE_ROW`, `DOC_STRING`, `EXAMPLES`

### 2. GherkinParser (`core/gherkin_parser.gd`)
Builds AST from token stream using recursive descent parsing.

**Parses**: Features, Rules, Scenarios, Scenario Outlines, Backgrounds, Steps, Data Tables, Doc Strings, Tags

### 3. GherkinAST (`core/gherkin_ast.gd`)
AST node definitions as inner classes:
- `Feature`, `Rule`, `Scenario`, `ScenarioOutline`, `Background`
- `Step`, `Examples`, `DataTable`, `DocString`, `Tag`

### 4. StepRegistry (`steps/step_registry.gd`)
Central registration and lookup for step definitions.

```gdscript
# Registration API
func given(pattern: String, callback: Callable) -> void
func when(pattern: String, callback: Callable) -> void
func then(pattern: String, callback: Callable) -> void
func step(pattern: String, callback: Callable) -> void  # Matches any keyword

# Lookup
func find_step(keyword: String, text: String) -> StepDefinition
```

### 5. StepMatcher (`steps/step_matcher.gd`)
Compiles Cucumber Expressions to RegEx patterns.

**Supported placeholders**:
- `{int}` - Integer: `-?\d+`
- `{float}` - Float: `-?\d*\.?\d+`
- `{word}` - Single word: `\S+`
- `{string}` - Quoted string: `"([^"]*)"`
- `{any}` or `{}` - Any text: `.*`

**Supported syntax**:
- Optional text: `apple(s)` matches "apple" or "apples"
- Alternation: `click/press` matches "click" or "press"

### 6. TestContext (`runner/test_context.gd`)
Shared state and assertions for step execution.

```gdscript
# State management
func set_value(key: String, value: Variant) -> void
func get_value(key: String, default: Variant = null) -> Variant

# Assertions
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> bool
func assert_true(condition: bool, message: String = "") -> bool
func assert_contains(container: Variant, item: Variant, message: String = "") -> bool
func assert_not_null(value: Variant, message: String = "") -> bool

# Optional scene management (when scene tree available)
func load_scene(path: String) -> Node
func get_node(path: String) -> Node
func free_scene() -> void
```

### 7. ScenarioExecutor (`runner/scenario_executor.gd`)
Executes a single scenario with Background support.

- Manages step execution order
- Handles And/But keyword resolution
- **Supports async steps via await** - detects if step returns a coroutine
- Stops on first step failure
- Emits progress signals

```gdscript
# Async step execution
func _execute_step(step: GherkinAST.Step) -> TestResult.StepResult:
    var step_def := _registry.find_step(keyword, step.text)
    var result = step_def.callback.callv([_context] + args)

    # Handle async steps
    if result is Coroutine:
        result = await result

    # Check for errors...
```

### 8. GherkinTestRunner (`runner/test_runner.gd`)
Orchestrates test execution across features.

- Discovers and parses feature files
- Loads step definition files
- Expands Scenario Outlines
- Applies tag filters
- Aggregates results

### 9. GherkinCLI (`runner/cli_runner.gd`)
Command-line interface entry point.

- Parses CLI arguments
- Configures runner
- Selects reporter
- Returns exit code

---

## User API: Step Definitions

### Explicit Registration Pattern

```gdscript
# tests/steps/inventory_steps.gd
extends RefCounted
class_name InventorySteps

func register_steps(registry: StepRegistry) -> void:
    registry.given("I have {int} items in my inventory", _have_items)
    registry.given("the player has no items", _no_items)
    registry.when("I pick up {int} {word}(s)", _pick_up_items)
    registry.when("I drop {string}", _drop_item)
    registry.then("I should have {int} items", _should_have_items)

func _have_items(ctx: TestContext, count: int) -> void:
    ctx.set_value("inventory_count", count)

func _no_items(ctx: TestContext) -> void:
    ctx.set_value("inventory_count", 0)

func _pick_up_items(ctx: TestContext, count: int, item_type: String) -> void:
    var current: int = ctx.get_value("inventory_count", 0)
    ctx.set_value("inventory_count", current + count)

func _drop_item(ctx: TestContext, item_name: String) -> void:
    var current: int = ctx.get_value("inventory_count", 0)
    ctx.set_value("inventory_count", current - 1)

func _should_have_items(ctx: TestContext, expected: int) -> void:
    var actual: int = ctx.get_value("inventory_count", 0)
    ctx.assert_equal(actual, expected, "Inventory count mismatch")
```

### Async Step Example

```gdscript
# Steps that need to wait can use await
func register_steps(registry: StepRegistry) -> void:
    registry.when("I wait for {float} seconds", _wait_seconds)
    registry.when("the animation {string} completes", _wait_animation)

func _wait_seconds(ctx: TestContext, seconds: float) -> void:
    await ctx.get_tree().create_timer(seconds).timeout

func _wait_animation(ctx: TestContext, anim_name: String) -> void:
    var player: AnimationPlayer = ctx.get_node("AnimationPlayer")
    player.play(anim_name)
    await player.animation_finished
```

---

## Feature File Syntax

```gherkin
@inventory @core
Feature: Inventory Management
  As a player
  I want to manage my inventory
  So that I can collect and use items

  Background:
    Given the player has no items

  Scenario: Picking up items
    When I pick up 5 apples
    Then I should have 5 items

  @slow
  Scenario Outline: Multiple pickups
    Given I have <initial> items
    When I pick up <pickup> <type>s
    Then I should have <total> items

    Examples:
      | initial | pickup | type   | total |
      | 0       | 5      | apple  | 5     |
      | 5       | 3      | sword  | 8     |
```

---

## Implementation Phases

### Phase 1: Core Parsing (Priority: High)
Files to create:
- `addons/godot_gherkin/core/gherkin_ast.gd`
- `addons/godot_gherkin/core/gherkin_lexer.gd`
- `addons/godot_gherkin/core/gherkin_parser.gd`

Tasks:
1. Define all AST node classes
2. Implement lexer with all token types
3. Implement recursive descent parser
4. Handle edge cases: multiline text, escaping, encoding

### Phase 2: Step Matching (Priority: High)
Files to create:
- `addons/godot_gherkin/steps/parameter_types.gd`
- `addons/godot_gherkin/steps/step_matcher.gd`
- `addons/godot_gherkin/steps/step_definition.gd`
- `addons/godot_gherkin/steps/step_registry.gd`

Tasks:
1. Implement built-in parameter types
2. Implement Cucumber Expression compiler
3. Implement step definition storage
4. Implement step lookup with pattern matching

### Phase 3: Test Execution (Priority: High)
Files to create:
- `addons/godot_gherkin/runner/test_context.gd`
- `addons/godot_gherkin/runner/test_result.gd`
- `addons/godot_gherkin/runner/scenario_executor.gd`
- `addons/godot_gherkin/runner/test_runner.gd`
- `addons/godot_gherkin/util/file_scanner.gd`

Tasks:
1. Implement TestContext with assertions
2. Implement result data structures
3. Implement scenario execution with background
4. Implement Scenario Outline expansion
5. Implement file discovery

### Phase 4: CLI Runner (Priority: High)
Files to create:
- `addons/godot_gherkin/runner/cli_runner.gd`
- `addons/godot_gherkin/runner/reporters/console_reporter.gd`
- `addons/godot_gherkin/runner/reporters/json_reporter.gd`
- `tests/run_tests.gd`

Tasks:
1. Implement CLI argument parsing
2. Implement console reporter with colors
3. Implement JSON reporter for AI/tools
4. Implement exit code handling
5. Test headless execution

### Phase 5: Editor Integration (Priority: Low)
Files to create:
- `addons/godot_gherkin/plugin.cfg`
- `addons/godot_gherkin/plugin.gd`
- `addons/godot_gherkin/editor/gherkin_dock.gd`
- `addons/godot_gherkin/editor/gherkin_dock.tscn`

Tasks:
1. Create EditorPlugin wrapper
2. Create dock panel UI
3. Wire up to core runner
4. Add run buttons and result display

### Phase 6: Polish (Priority: Medium)
- Tag filtering implementation
- JUnit XML reporter for CI
- Custom parameter type API
- Documentation and examples

---

## Headless Execution Guarantees

1. **No UI dependencies**: Core classes never reference Control, EditorPlugin, or visual nodes
2. **No SceneTree required**: Runner works with just `extends RefCounted`
3. **Minimal imports**: Only use built-in GDScript types where possible
4. **File I/O only**: Use FileAccess, DirAccess - no ResourceLoader for non-essential files
5. **Signal-based progress**: Reporters connect to signals, no blocking UI updates
6. **Deterministic output**: Same input produces same output, suitable for diffing

---

## Testing the Addon

Self-test suite in `addons/godot_gherkin/tests/`:

```gherkin
Feature: Gherkin Parser
  Scenario: Parse simple feature
    Given a feature file with content:
      """
      Feature: Test
        Scenario: Example
          Given something
      """
    When I parse the feature
    Then the feature name should be "Test"
    And there should be 1 scenario

Feature: Step Matching
  Scenario: Match integer parameter
    Given a step pattern "I have {int} items"
    When I match "I have 42 items"
    Then the match should succeed
    And parameter 1 should equal 42
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | Error (parse error, missing steps, etc.) |

---

## Critical Implementation Files

1. **`core/gherkin_parser.gd`** - All execution depends on correct parsing
2. **`steps/step_registry.gd`** - Defines user-facing registration API
3. **`steps/step_matcher.gd`** - Pattern matching correctness is critical
4. **`runner/scenario_executor.gd`** - Step execution and context management
5. **`runner/cli_runner.gd`** - Primary entry point for headless execution
6. **`runner/reporters/json_reporter.gd`** - Machine-readable output for AI tools
