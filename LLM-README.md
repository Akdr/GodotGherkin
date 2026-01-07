# GodotGherkin - LLM Reference

This document is optimized for AI assistants and LLMs working with GodotGherkin.

## Quick Context

GodotGherkin is a BDD testing framework for Godot 4.3+. It parses `.feature` files (Gherkin syntax) and executes GDScript step definitions.

**Primary use case**: Headless CLI execution for AI-assisted development and CI/CD.

**Important**: This addon uses preload constants instead of `class_name` for headless compatibility.

**Version**: 0.4.1 - Added code coverage with LCOV output for CI/CD integration.

## File Structure

```
addons/godot_gherkin/
├── core/
│   ├── gherkin_ast.gd      # AST nodes: Feature, Scenario, Step, etc.
│   ├── gherkin_lexer.gd    # Tokenizer for .feature files
│   └── gherkin_parser.gd   # Recursive descent parser
├── steps/
│   ├── parameter_types.gd  # {int}, {float}, {string}, {word}, {any}
│   ├── step_matcher.gd     # Cucumber Expression → RegEx compiler
│   ├── step_definition.gd  # Step pattern + callback storage
│   └── step_registry.gd    # given/when/then registration API
├── runner/
│   ├── test_context.gd     # State storage + assertions
│   ├── test_result.gd      # Result classes with to_dict()/to_json()
│   ├── scenario_executor.gd # Executes scenarios (async-aware)
│   ├── test_runner.gd      # Orchestrates test execution
│   ├── cli_runner.gd       # CLI argument parsing
│   └── reporters/
│       ├── console_reporter.gd  # Human-readable output
│       └── json_reporter.gd     # Machine-readable JSON
├── util/
│   └── file_scanner.gd     # Discovers .feature and *_steps.gd files
├── coverage/
│   ├── coverage_tracker.gd    # Singleton for hit tracking
│   ├── coverage_reporter.gd   # LCOV format + console summary
│   ├── gdscript_lexer.gd      # GDScript tokenizer
│   └── gdscript_instrumentor.gd # Source instrumentation
├── plugin.gd               # EditorPlugin (optional)
└── plugin.cfg

tests/
├── features/*.feature      # Gherkin feature files
├── steps/*_steps.gd        # Step definition files
└── run_tests.gd            # CLI entry point
```

## Running Tests

```bash
# All tests
godot --headless --script tests/run_tests.gd

# JSON output (recommended for AI parsing)
godot --headless --script tests/run_tests.gd -- --format json

# Specific feature
godot --headless --script tests/run_tests.gd -- --feature tests/features/example.feature

# With tags
godot --headless --script tests/run_tests.gd -- --tags @smoke --tags ~@slow

# Verbose console output
godot --headless --script tests/run_tests.gd -- --verbose
```

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed
- `2`: Error (parse error, missing files, invalid args)

## JSON Output Schema

```json
{
  "success": boolean,
  "summary": {
    "total_scenarios": int,
    "passed": int,
    "failed": int,
    "skipped": int,
    "duration_ms": float
  },
  "features": [{
    "name": string,
    "file": string,
    "scenarios": [{
      "name": string,
      "status": "passed" | "failed" | "skipped" | "undefined",
      "duration_ms": float,
      "steps": [{
        "keyword": "Given" | "When" | "Then" | "And" | "But",
        "text": string,
        "status": "passed" | "failed" | "skipped" | "undefined",
        "duration_ms": float,
        "error": string | null,
        "line": int
      }],
      "error": string | null
    }]
  }],
  "undefined_steps": [string],
  "pending_steps": [string]
}
```

## Creating Feature Files

Location: `tests/features/*.feature`

```gherkin
@tag1 @tag2
Feature: Feature Name
  Optional description

  Background:
    Given common setup step

  Scenario: Scenario Name
    Given precondition with {int} parameter
    When action with "string parameter"
    Then expected outcome

  Scenario Outline: Parameterized test
    Given value is <input>
    Then result is <output>

    Examples:
      | input | output |
      | 1     | 2      |
      | 5     | 10     |
```

## Creating Step Definitions

Location: `tests/steps/*_steps.gd`

**Required**: File must extend RefCounted and have `register_steps(registry)` method.

```gdscript
extends RefCounted

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
    # Pattern → Callback mapping
    registry.given("pattern with {int}", _method_name)
    registry.when("pattern with {string}", _method_name)
    registry.then("pattern with {float}", _method_name)
    registry.step("any keyword pattern", _method_name)  # Matches Given/When/Then/And/But


# Step implementation signature: func(ctx, ...params) -> void
func _method_name(ctx: TestContextScript, param: int) -> void:
    ctx.set_value("key", param)
    ctx.assert_equal(actual, expected)
```

### Critical: Use `registry.step()` for And/But Steps

`And` and `But` inherit the previous keyword's context. If you have:

```gherkin
Given I am logged in
And I navigate to "settings"
```

The `And I navigate to "settings"` is treated as a **Given**, not a When. Use `registry.step()` for steps that can appear with any keyword:

```gdscript
# BAD - Won't match "And I navigate to X" after a Given
registry.when("I navigate to {string}", _navigate)

# GOOD - Matches any keyword
registry.step("I navigate to {string}", _navigate)
```

## Parameter Types

| Placeholder | Regex | GDScript Type |
|-------------|-------|---------------|
| `{int}` | `-?\d+` | `int` |
| `{float}` | `-?\d*\.?\d+` | `float` |
| `{word}` | `\S+` | `String` |
| `{string}` | `"..."` or `'...'` | `String` (quotes stripped) |
| `{any}` or `{}` | `.*` | `String` |

**Optional text**: `apple(s)` matches "apple" or "apples"
**Alternation**: `click/press` matches "click" or "press"

## TestContext API

```gdscript
# State (scenario-scoped, cleared between scenarios)
ctx.set_value(key: String, value: Variant)
ctx.get_value(key: String, default: Variant = null) -> Variant
ctx.has_value(key: String) -> bool

# Assertions (throw on failure, stopping the scenario)
ctx.assert_equal(actual, expected, message?)
ctx.assert_not_equal(actual, not_expected, message?)
ctx.assert_true(condition, message?)
ctx.assert_false(condition, message?)
ctx.assert_null(value, message?)
ctx.assert_not_null(value, message?)
ctx.assert_contains(container, item, message?)
ctx.assert_not_contains(container, item, message?)
ctx.assert_greater(actual, threshold, message?)        # Alias: assert_greater_than
ctx.assert_less(actual, threshold, message?)           # Alias: assert_less_than
ctx.assert_greater_or_equal(actual, threshold, message?)
ctx.assert_less_or_equal(actual, threshold, message?)
ctx.fail(message)  # Explicit failure

# Scene management (requires SceneTree)
ctx.load_scene(path: String) -> Node
ctx.get_scene() -> Node
ctx.get_node(path: String) -> Node
ctx.free_scene()
ctx.get_tree() -> SceneTree
```

### State Management Pattern

Use TestContext for sharing state between steps within a scenario:

```gdscript
# Store calculated values
func _when_calculate(ctx: TestContextScript, a: int, b: int) -> void:
    ctx.set_value("result", a + b)

# Retrieve with default fallback
func _then_verify(ctx: TestContextScript, expected: int) -> void:
    var actual: int = ctx.get_value("result", 0)
    ctx.assert_equal(actual, expected, "Calculation mismatch")
```

## Tag-Based Step Scoping

Steps can be scoped to specific tags using `.for_tags()`, enabling the same pattern to have different implementations for different contexts:

```gdscript
# Scoped steps - only match when scenario has the specified tag
registry.then("I should see a {string} button", _check_pause_button).for_tags(["@pause_menu"])
registry.then("I should see a {string} button", _check_main_menu_button).for_tags(["@main_menu"])

# Fallback unscoped step - matches when no scoped step matches
registry.then("I should see a {string} button", _check_generic_button)
```

**Tag Inheritance**: Scenarios inherit their parent Feature's tags. A scenario without `@pause_menu` will still match `.for_tags(["@pause_menu"])` if the Feature has that tag:

```gherkin
@pause_menu
Feature: Pause Menu
  # All scenarios inherit @pause_menu tag

  Scenario: Resume button  # Inherits @pause_menu, matches scoped steps
    Then I should see a "Resume" button
```

**Priority**: Scoped steps take priority over unscoped steps. If both match, the scoped step wins.

## Async Steps

Steps can use `await`:

```gdscript
func _wait_for_signal(ctx: TestContextScript) -> void:
    await ctx.get_tree().create_timer(1.0).timeout


func _wait_animation(ctx: TestContextScript) -> void:
    var anim: AnimationPlayer = ctx.get_node("AnimationPlayer")
    await anim.animation_finished
```

## Mock Pattern for Autoloads

Systems referencing autoloads (EventBus, GameManager) won't compile in headless mode. Mock the behavior:

```gdscript
# Instead of testing real SubSceneManager (references EventBus),
# mock the state pattern:

func _init_mock_state(ctx: TestContextScript) -> void:
    ctx.set_value("current_location", "")
    ctx.set_value("history", [])


func _navigate_to(ctx: TestContextScript, destination: String) -> void:
    var history: Array = ctx.get_value("history", [])
    history.append(destination)
    ctx.set_value("history", history)
    ctx.set_value("current_location", destination)


func _verify_location(ctx: TestContextScript, expected: String) -> void:
    ctx.assert_equal(ctx.get_value("current_location"), expected)
```

## Key Classes (via preload)

| Script | Preload Path | Purpose |
|--------|--------------|---------|
| `GherkinCLIScript` | `runner/cli_runner.gd` | CLI entry point |
| `GherkinTestRunnerScript` | `runner/test_runner.gd` | Test orchestration |
| `StepRegistryScript` | `steps/step_registry.gd` | Step registration |
| `TestContextScript` | `runner/test_context.gd` | State + assertions |
| `TestResultScript` | `runner/test_result.gd` | Result data |
| `GherkinParserScript` | `core/gherkin_parser.gd` | Parser |
| `GherkinLexerScript` | `core/gherkin_lexer.gd` | Lexer |
| `GherkinASTScript` | `core/gherkin_ast.gd` | AST nodes |

All paths relative to `res://addons/godot_gherkin/`.

## Common Tasks

### Add a new feature test

1. Create `tests/features/new_feature.feature`
2. Create `tests/steps/new_feature_steps.gd` with `register_steps()`
3. Run: `godot --headless --script tests/run_tests.gd`

### Check for undefined steps

```bash
godot --headless --script tests/run_tests.gd -- --format json | jq '.undefined_steps'
```

### Run specific tags

```bash
# Include @smoke, exclude @slow
godot --headless --script tests/run_tests.gd -- --tags @smoke --tags ~@slow
```

### Debug a failing test

```bash
godot --headless --script tests/run_tests.gd -- --verbose --fail-fast
```

## Step Analysis (Automatic)

Before running tests, GodotGherkin automatically analyzes step definitions and prints warnings for:

1. **Load Errors**: Step files that fail to load (parse errors, missing `register_steps()`)
2. **Duplicate Patterns**: Same pattern in multiple files without tag scoping

Output (only shown if issues found):
```
=== Step File Load Errors ===
  ✗ res://tests/steps/broken_steps.gd
    Could not load script (parse error?)

=== Duplicate Step Definitions ===
  Given 'I have {int} items'
    - res://tests/steps/inventory_steps.gd
    - res://tests/steps/cart_steps.gd
```

**Note**: Scoped steps (`.for_tags()`) with same pattern are NOT duplicates.

## Code Coverage

Line-level coverage with LCOV output. Single command handles everything.

```bash
# Run with coverage (instruments, runs, restores automatically)
godot --headless --script tests/run_tests.gd -- \
  --coverage --coverage-include "res://src/**/*.gd"

# Save LCOV to file
godot --headless --script tests/run_tests.gd -- \
  --coverage --coverage-include "res://src/**/*.gd" \
  --coverage-output coverage/lcov.info
```

### Coverage CLI Options

| Option | Description |
|--------|-------------|
| `--coverage` | Enable coverage (instruments, runs, restores automatically) |
| `--coverage-output <path>` | Write LCOV to file instead of stdout |
| `--coverage-include <glob>` | Files to include (repeatable) |
| `--coverage-exclude <glob>` | Files to exclude (repeatable) |

### Coverage Output

Console summary after tests:
```
=== Coverage Summary ===
  src/game.gd    85.7% (12/14 lines)
  src/player.gd  100%  (8/8 lines)
  Total:         89.1% (20/22 lines)

Coverage report written to: coverage/lcov.info
```

LCOV format for Codecov/Coveralls:
```
TN:GodotGherkin Coverage
SF:res://src/game.gd
DA:10,5
DA:11,5
DA:15,0
LF:3
LH:2
end_of_record
```

### Key Coverage Classes

| Script | Purpose |
|--------|---------|
| `CoverageTrackerScript` | Singleton for recording line hits |
| `CoverageReporterScript` | LCOV generation + console summary |
| `GDScriptLexerScript` | Tokenizes GDScript for instrumentation |
| `GDScriptInstrumentorScript` | Transforms source with hit() calls |

## Limitations

- No editor integration yet (EditorPlugin is a stub)
- No JUnit XML reporter (JSON is primary output)
- Custom parameter types not exposed via API (can modify `parameter_types.gd`)
- Tag expressions are simple (no AND/OR logic, just include/exclude)

## Makefile Integration

Common targets for projects using GodotGherkin:

```makefile
test-bdd:
	godot --headless --script tests/run_tests.gd

test-bdd-verbose:
	godot --headless --script tests/run_tests.gd -- --verbose

test-bdd-json:
	godot --headless --script tests/run_tests.gd -- --format json --output test-results.json

test-bdd-coverage:
	godot --headless --script tests/run_tests.gd -- --coverage --coverage-include "res://src/**/*.gd" --coverage-output coverage/lcov.info
```
