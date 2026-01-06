@step_scoping
Feature: Step Scoping
  Verify that steps can be scoped to specific tags to prevent pattern collisions.

  @pause_menu
  Scenario: Pause menu button check
    Given I am on the pause menu
    Then I should see a "Resume" button

  @multiplayer
  Scenario: Multiplayer button check
    Given I am in multiplayer lobby
    Then I should see a "Ready" button

  Scenario: Unscoped scenario uses fallback step
    Given I am on an unknown screen
    Then I should see a "Generic" button
