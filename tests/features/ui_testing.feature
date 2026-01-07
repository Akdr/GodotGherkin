@ui
Feature: UI Testing
  Test the built-in UI testing capabilities

  Scenario: Load scene and check button visibility
    Given I load scene "res://tests/scenes/test_menu.tscn"
    Then button "Start Game" should be visible
    And button "Options" should be visible
    And button "Quit" should be visible

  Scenario: Check button states
    Given I load scene "res://tests/scenes/test_menu.tscn"
    Then button "Start Game" should be enabled
    And button "Options" should be enabled
    And button "Quit" should be disabled

  Scenario: Check node text content
    Given I load scene "res://tests/scenes/test_menu.tscn"
    Then "TitleLabel" should have text "Test Menu"

  Scenario: Query syntax for finding nodes
    Given I load scene "res://tests/scenes/test_menu.tscn"
    Then "Button:text=Start Game" should be visible
    And "Label:first" should have text "Test Menu"

  Scenario: Find nodes by name
    Given I load scene "res://tests/scenes/test_menu.tscn"
    Then "StartButton" should exist
    And "OptionsButton" should exist
    And "QuitButton" should exist
    And "TitleLabel" should exist
