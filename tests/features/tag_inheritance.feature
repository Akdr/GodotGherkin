@inherited_tag
Feature: Tag Inheritance
  Scenarios inherit feature tags for both tag filtering and step scoping.
  When running with --tags @inherited_tag, scenarios in this feature will match
  even without the tag directly. Steps scoped with for_tags(["@inherited_tag"])
  will also match scenarios that inherit the tag from the feature.

  Scenario: Scenario inherits feature tag
    Given I am testing tag inheritance
    Then the step scoped to inherited_tag should match

  @extra_tag
  Scenario: Scenario with own tag still inherits feature tag
    Given I am testing tag inheritance
    Then the step scoped to inherited_tag should match
