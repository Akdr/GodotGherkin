# GodotGherkin - LLM Reference

This document is optimized for AI assistants and LLMs working with GodotGherkin.

## Quick Context

GodotGherkin is a BDD testing framework for Godot 4.3+. It parses `.feature` files (Gherkin syntax) and executes GDScript step definitions.

**Primary use case**: Headless CLI execution for AI-assisted development and CI/CD.

**Important**: This addon uses preload constants instead of `class_name` for headless compatibility.

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
ctx.assert_greater(actual, threshold, message?)
ctx.assert_less(actual, threshold, message?)
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
```
