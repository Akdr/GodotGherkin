# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GodotGherkin is a BDD testing framework for Godot 4.3+ that parses `.feature` files (Gherkin syntax) and executes GDScript step definitions. It's designed for headless CLI execution in CI/CD pipelines and AI-assisted development.

**Important**: This addon uses `preload()` constants instead of `class_name` for headless compatibility.

## Commands

### Running Tests

```bash
# Run all tests (script runner)
godot --headless --script tests/run_tests.gd

# Run all tests (scene runner - for UI tests/autoloads)
godot --headless res://addons/godot_gherkin/runner/scene_runner.tscn

# Verbose output
godot --headless --script tests/run_tests.gd -- --verbose

# Run specific feature file
godot --headless --script tests/run_tests.gd -- --feature tests/features/example.feature

# Run by tag
godot --headless --script tests/run_tests.gd -- --tags @ui

# JSON output
godot --headless --script tests/run_tests.gd -- --format json
```

### Linting and Formatting

```bash
gdlint addons/godot_gherkin/**/*.gd
gdformat addons/godot_gherkin/**/*.gd
```

## Architecture

### Core Pipeline

1. **Lexer** (`core/gherkin_lexer.gd`) - Tokenizes `.feature` files
2. **Parser** (`core/gherkin_parser.gd`) - Recursive descent parser producing AST
3. **AST** (`core/gherkin_ast.gd`) - Node types: Feature, Scenario, ScenarioOutline, Step, DataTable, DocString
4. **Step Matcher** (`steps/step_matcher.gd`) - Compiles Cucumber Expressions to RegEx
5. **Step Registry** (`steps/step_registry.gd`) - Maps patterns to callbacks via `given()`, `when()`, `then()`, `step()`
6. **Scenario Executor** (`runner/scenario_executor.gd`) - Executes steps with async support
7. **Test Runner** (`runner/test_runner.gd`) - Orchestrates feature/scenario execution
8. **CLI Runner** (`runner/cli_runner.gd`) - Parses CLI args, coordinates reporters

### Key Design Patterns

**Preload Constants**: All cross-file references use preload to avoid `class_name` issues in headless mode:
```gdscript
const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
```

**And/But Keyword Resolution**: `And`/`But` inherit the previous keyword's context. The `_resolve_keyword()` method in `scenario_executor.gd` tracks state.

**Tag-Scoped Steps**: Steps can be scoped via `.for_tags()`. Scoped steps have priority over unscoped. Tag inheritance flows from Feature → Scenario.

**Async Step Execution**: Steps returning a `Signal` are awaited. Use `ctx.await_frames()`, `ctx.await_idle()`, or return explicit signals.

### Test Context (`runner/test_context.gd`)

Central class providing:
- **State management**: `set_value()`, `get_value()` - scenario-scoped, cleared between scenarios
- **Assertions**: `assert_equal()`, `assert_true()`, `assert_contains()`, etc.
- **Scene management**: `load_scene()`, `get_node()`, `free_scene()`
- **Input simulation**: `simulate_click()`, `simulate_key_press()`, `simulate_text_input()`
- **Node finding**: `find_button()`, `find_node_by_text()`, `query_node()` with query syntax
- **Layout assertions**: `assert_below()`, `assert_right_of()`, `assert_within_viewport()`

### Step Definition Files

Located in `tests/steps/*_steps.gd`. Must:
- Extend `RefCounted`
- Implement `register_steps(registry: StepRegistryScript)`
- Use preload for type hints

```gdscript
extends RefCounted

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")

func register_steps(registry: StepRegistryScript) -> void:
    registry.given("pattern with {int}", _method)
    registry.step("any keyword pattern", _method)  # Use for And/But compatibility

func _method(ctx: TestContextScript, param: int) -> void:
    ctx.set_value("key", param)
```

### Parameter Types

- `{int}` → `int`
- `{float}` → `float`
- `{string}` → `String` (quotes stripped)
- `{word}` → `String` (no whitespace)
- `{any}` → `String` (anything)
- Optional: `apple(s)` matches "apple" or "apples"
- Alternation: `click/press` matches "click" or "press"

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed
- `2`: Error (parse error, missing files, invalid args)

## File Locations

- **Addon source**: `addons/godot_gherkin/`
- **Feature files**: `tests/features/*.feature`
- **Step definitions**: `tests/steps/*_steps.gd`
- **Test runner**: `tests/run_tests.gd`
- **Test scenes**: `tests/scenes/*.tscn`
