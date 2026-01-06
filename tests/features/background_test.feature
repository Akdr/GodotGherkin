@background_test
Feature: Background Test
  Verify that Background steps execute before each scenario.

  Background:
    Given the counter is initialized to 100

  Scenario: First scenario uses background value
    Then the counter should be 100

  Scenario: Second scenario also gets fresh background
    When I increment the counter by 5
    Then the counter should be 105
