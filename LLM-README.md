# GodotGherkin - LLM Reference

This document is optimized for AI assistants and LLMs working with GodotGherkin.

## Quick Context

GodotGherkin is a BDD testing framework for Godot 4.5+. It parses `.feature` files (Gherkin syntax) and executes GDScript step definitions.

**Primary use case**: Headless CLI execution for AI-assisted development and CI/CD.

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

**Required**: File must have `register_steps(registry: StepRegistry)` method.

```gdscript
extends RefCounted

func register_steps(registry: StepRegistry) -> void:
    # Pattern → Callback mapping
    registry.given("pattern with {int}", _method_name)
    registry.when("pattern with {string}", _method_name)
    registry.then("pattern with {float}", _method_name)
    registry.step("any keyword pattern", _method_name)  # Matches Given/When/Then

# Step implementation signature: func(ctx: TestContext, ...params) -> void
func _method_name(ctx: TestContext, param: int) -> void:
    ctx.set_value("key", param)
    ctx.assert_equal(actual, expected)
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

# Assertions (all return bool, false = failure)
ctx.assert_equal(actual, expected, message?)
ctx.assert_not_equal(actual, not_expected, message?)
ctx.assert_true(condition, message?)
ctx.assert_false(condition, message?)
ctx.assert_null(value, message?)
ctx.assert_not_null(value, message?)
ctx.assert_contains(container, item, message?)
ctx.assert_greater(actual, threshold, message?)
ctx.assert_less(actual, threshold, message?)
ctx.fail(message)

# Scene management (requires SceneTree)
ctx.load_scene(path: String) -> Node
ctx.get_scene() -> Node
ctx.get_node(path: String) -> Node
ctx.free_scene()
ctx.get_tree() -> SceneTree
```

## Async Steps

Steps can use `await`:

```gdscript
func _wait_for_signal(ctx: TestContext) -> void:
    await ctx.get_tree().create_timer(1.0).timeout

func _wait_animation(ctx: TestContext) -> void:
    var anim: AnimationPlayer = ctx.get_node("AnimationPlayer")
    await anim.animation_finished
```

## Key Classes

| Class | Purpose |
|-------|---------|
| `GherkinCLI` | CLI entry point, argument parsing |
| `GherkinTestRunner` | Orchestrates test execution |
| `ScenarioExecutor` | Runs individual scenarios |
| `StepRegistry` | Step registration (given/when/then) |
| `StepDefinition` | Pattern matching + callback |
| `TestContext` | State + assertions |
| `TestResult.*` | Result data structures |
| `GherkinParser` | Parses .feature files → AST |
| `GherkinLexer` | Tokenizes .feature files |
| `GherkinAST.*` | AST node classes |

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

## Limitations

- No editor integration yet (EditorPlugin is a stub)
- No JUnit XML reporter (JSON is primary output)
- Custom parameter types not exposed via API (can modify `parameter_types.gd`)
- Tag expressions are simple (no AND/OR logic, just include/exclude)
