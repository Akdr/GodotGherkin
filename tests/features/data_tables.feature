@data_tables
Feature: Data Tables and Doc Strings
  Verify that data tables and doc strings are passed to step callbacks.

  Scenario: Data table with key-value pairs
    Given the player has the following stats:
      | stat             | value |
      | total_runs       | 30    |
      | total_victories  | 8     |
      | enemies_defeated | 750   |
    Then the player should have 30 total runs
    And the player should have 8 total victories

  Scenario: Data table with multiple columns
    Given the following users exist:
      | name  | role  | level |
      | Alice | admin | 50    |
      | Bob   | user  | 25    |
      | Carol | mod   | 35    |
    Then there should be 3 users
    And user "Alice" should be an admin

  Scenario: Doc string content
    Given a JSON configuration:
      """json
      {
        "debug": true,
        "max_players": 4
      }
      """
    Then the config should have debug enabled
