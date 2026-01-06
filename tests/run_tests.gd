#!/usr/bin/env -S godot --headless --script
extends SceneTree
## GodotGherkin test runner entry point.
##
## Run with: godot --headless --script tests/run_tests.gd
## For options: godot --headless --script tests/run_tests.gd -- --help


func _init() -> void:
	var cli := GherkinCLI.new(self)
	var exit_code := await cli.run(OS.get_cmdline_user_args())
	quit(exit_code)
