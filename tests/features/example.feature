@example
Feature: Calculator
  As a user
  I want to perform basic arithmetic
  So that I can calculate values

  Background:
    Given the calculator is reset

  Scenario: Addition
    When I add 5 and 3
    Then the result should be 8

  Scenario: Subtraction
    When I subtract 3 from 10
    Then the result should be 7

  @smoke
  Scenario: Multiplication
    When I multiply 4 by 6
    Then the result should be 24

  Scenario Outline: Multiple operations
    Given the calculator shows <initial>
    When I add <addend>
    Then the result should be <result>

    Examples:
      | initial | addend | result |
      | 0       | 5      | 5      |
      | 10      | 3      | 13     |
      | -5      | 10     | 5      |
