#!/usr/bin/env -S godot --headless --script
extends SceneTree
## GodotGherkin test runner entry point.
##
## Run with: godot --headless --script tests/run_tests.gd
## For options: godot --headless --script tests/run_tests.gd -- --help

const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")


func _init() -> void:
	var cli := GherkinCLIScript.new(self)
	var exit_code := await cli.run(OS.get_cmdline_user_args())
	quit(exit_code)
