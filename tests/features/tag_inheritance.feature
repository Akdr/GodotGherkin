@inherited_tag
Feature: Tag Inheritance
  Scenarios inherit feature tags for step scoping with for_tags().
  This verifies that steps scoped to a feature-level tag will match
  scenarios that don't have the tag directly, but inherit it from the feature.

  Scenario: Scenario inherits feature tag
    Given I am testing tag inheritance
    Then the step scoped to inherited_tag should match

  @extra_tag
  Scenario: Scenario with own tag still inherits feature tag
    Given I am testing tag inheritance
    Then the step scoped to inherited_tag should match
