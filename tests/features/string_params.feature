@string_params
Feature: Multiple String Parameters
  Verify that multiple {string} parameters in a single step are captured correctly.

  Scenario: Two string parameters
    Given a section named "Combat"
    Then the "Combat" section should mention "attack"

  Scenario: Three string parameters
    Then copying "hello" to "world" should produce "hello world"

  Scenario: Mixed parameter types
    Then the "Settings" section at index 3 should contain "options"
