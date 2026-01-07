extends RefCounted
## Lexer for GDScript source code (coverage instrumentation focused).
##
## Self-reference for headless mode compatibility
const GDScriptLexerScript = preload("res://addons/godot_gherkin/coverage/gdscript_lexer.gd")
##
## Tokenizes GDScript source for instrumentation purposes.
## Focused on identifying executable lines while tracking strings/comments.

enum TokenType {
	# Keywords that start blocks (not executable themselves)
	CLASS,
	FUNC,
	SIGNAL,
	ENUM,
	CONST,
	# Control flow (executable)
	IF,
	ELIF,
	ELSE,
	FOR,
	WHILE,
	MATCH,
	WHEN,
	# Statements (executable)
	VAR,
	RETURN,
	BREAK,
	CONTINUE,
	PASS,
	AWAIT,
	YIELD,
	ASSERT,
	# Other
	ANNOTATION,  # @export, @onready, etc.
	COMMENT,
	STRING,
	IDENTIFIER,
	NUMBER,
	OPERATOR,
	PUNCTUATION,
	INDENT,
	NEWLINE,
	EOF,
}


class Token:
	extends RefCounted
	var type: TokenType
	var value: String
	var line: int
	var column: int

	func _init(p_type: TokenType, p_value: String, p_line: int, p_col: int) -> void:
		type = p_type
		value = p_value
		line = p_line
		column = p_col


## Keywords that indicate non-executable declaration lines
const DECLARATION_KEYWORDS := ["class", "class_name", "extends", "signal", "enum", "const"]

## Keywords that indicate executable lines
const EXECUTABLE_KEYWORDS := [
	"var",
	"if",
	"elif",
	"else",
	"for",
	"while",
	"match",
	"when",
	"return",
	"break",
	"continue",
	"pass",
	"await",
	"yield",
	"assert",
	"print",
	"printerr",
	"push_error",
	"push_warning"
]

## Keywords that start function definitions
const FUNC_KEYWORDS := ["func", "static"]

var _source: String = ""
var _pos: int = 0
var _line: int = 1
var _column: int = 1
var _tokens: Array[Token] = []


## Tokenize the source and return list of tokens.
func tokenize(source: String) -> Array[Token]:
	_source = source
	_pos = 0
	_line = 1
	_column = 1
	_tokens = []

	while _pos < _source.length():
		_scan_token()

	_tokens.append(Token.new(TokenType.EOF, "", _line, _column))
	return _tokens


## Analyze source and return array of executable line numbers.
func get_executable_lines(source: String) -> Array[int]:
	var lines: Array[int] = []
	var source_lines := source.split("\n")

	for i in range(source_lines.size()):
		var line_num := i + 1
		var line_text := source_lines[i]

		if _is_executable_line(line_text, source_lines, i):
			lines.append(line_num)

	return lines


## Check if a line is executable (should be instrumented).
func _is_executable_line(line: String, all_lines: Array, line_idx: int) -> bool:
	var stripped := line.strip_edges()

	# Check for non-executable patterns first
	if _should_skip_line(stripped):
		return false

	# Class-level variable declarations are not executable (no indentation)
	# Only function-level vars (indented) should be instrumented
	if stripped.begins_with("var "):
		var indent := _get_leading_whitespace(line)
		if indent.is_empty():
			return false

	# Check for executable patterns
	return _is_executable_pattern(stripped)


## Get leading whitespace from a line.
func _get_leading_whitespace(line: String) -> String:
	var result := ""
	for c in line:
		if c == " " or c == "\t":
			result += c
		else:
			break
	return result


## Check if a line should be skipped (non-executable).
func _should_skip_line(stripped: String) -> bool:
	# Empty lines
	if stripped.is_empty():
		return true

	# Comment-only lines
	if stripped.begins_with("#"):
		return true

	# Annotations (@export, @onready, etc.)
	if stripped.begins_with("@"):
		return true

	# Declaration keywords that aren't executable
	var skip_prefixes := [
		"class_name ", "extends ", "class ", "signal ", "enum ", "const ", "func ", "static func "
	]
	for prefix in skip_prefixes:
		if stripped.begins_with(prefix):
			return true

	# Closing braces/brackets
	if stripped in [")", "]", "}", "):", "]:", "}:"]:
		return true

	# Multiline string markers (docstrings)
	if stripped.begins_with('"""') or stripped.begins_with("'''"):
		return true

	return false


## Check if a line matches executable patterns.
func _is_executable_pattern(stripped: String) -> bool:
	# Check executable keywords
	if _matches_executable_keyword(stripped):
		return true

	# Function calls (identifier followed by parenthesis)
	var call_regex := RegEx.new()
	call_regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*\\s*\\(")
	if call_regex.search(stripped):
		return true

	# Method calls (something.method())
	if ".(" in stripped or ")." in stripped:
		return true

	# Assignment statements (but not comparisons)
	if _is_assignment(stripped):
		return true

	# Expressions ending with ) are likely function calls
	if stripped.ends_with(")"):
		return true

	# await expressions
	if "await " in stripped:
		return true

	return false


## Check if line starts with an executable keyword.
func _matches_executable_keyword(stripped: String) -> bool:
	for keyword in EXECUTABLE_KEYWORDS:
		if stripped.begins_with(keyword + " ") or stripped.begins_with(keyword + "("):
			return true
		if stripped == keyword or stripped == keyword + ":":
			return true
	return false


## Check if line is an assignment statement.
func _is_assignment(stripped: String) -> bool:
	if "=" not in stripped or stripped.begins_with("#"):
		return false

	var eq_pos := stripped.find("=")
	if eq_pos <= 0:
		return false

	# Make sure it's not == or != comparison
	var before := stripped[eq_pos - 1]
	return before not in ["=", "!", "<", ">"]


## Scan a single token from current position.
func _scan_token() -> void:
	_skip_whitespace_same_line()

	if _pos >= _source.length():
		return

	var c := _source[_pos]

	# Newline
	if c == "\n":
		_tokens.append(Token.new(TokenType.NEWLINE, "\n", _line, _column))
		_advance()
		_line += 1
		_column = 1
		return

	# Comment
	if c == "#":
		_scan_comment()
		return

	# String
	if c == '"' or c == "'":
		_scan_string(c)
		return

	# Annotation
	if c == "@":
		_scan_annotation()
		return

	# Number
	if c.is_valid_int() or (c == "-" and _peek(1).is_valid_int()):
		_scan_number()
		return

	# Identifier or keyword
	if c == "_" or c.to_upper() != c.to_lower():  # is_alpha check
		_scan_identifier()
		return

	# Operators and punctuation
	_scan_operator()


## Skip whitespace on the same line (not newlines).
func _skip_whitespace_same_line() -> void:
	while _pos < _source.length():
		var c := _source[_pos]
		if c == " " or c == "\t" or c == "\r":
			_advance()
		else:
			break


## Advance position by one character.
func _advance() -> String:
	var c := _source[_pos]
	_pos += 1
	_column += 1
	return c


## Peek at character at offset from current position.
func _peek(offset: int = 0) -> String:
	var idx := _pos + offset
	if idx >= _source.length():
		return ""
	return _source[idx]


## Scan a comment (# to end of line).
func _scan_comment() -> void:
	var start_col := _column
	var value := ""
	while _pos < _source.length() and _source[_pos] != "\n":
		value += _advance()
	_tokens.append(Token.new(TokenType.COMMENT, value, _line, start_col))


## Scan a string literal.
func _scan_string(quote: String) -> void:
	var start_col := _column
	var start_line := _line
	var value := _advance()  # opening quote

	# Check for triple quote
	var is_multiline := false
	if _peek() == quote and _peek(1) == quote:
		is_multiline = true
		value += _advance() + _advance()

	# Scan string content
	while _pos < _source.length():
		var c := _source[_pos]

		if c == "\n":
			if is_multiline:
				value += _advance()
				_line += 1
				_column = 1
			else:
				break  # Unterminated string

		elif c == "\\":
			# Escape sequence
			value += _advance()
			if _pos < _source.length():
				value += _advance()

		elif c == quote:
			if is_multiline:
				if _peek(1) == quote and _peek(2) == quote:
					value += _advance() + _advance() + _advance()
					break
				else:
					value += _advance()
			else:
				value += _advance()
				break
		else:
			value += _advance()

	_tokens.append(Token.new(TokenType.STRING, value, start_line, start_col))


## Scan an annotation (@something).
func _scan_annotation() -> void:
	var start_col := _column
	var value := _advance()  # @

	while _pos < _source.length():
		var c := _source[_pos]
		if c == "_" or c.is_valid_int() or c.to_upper() != c.to_lower():
			value += _advance()
		else:
			break

	_tokens.append(Token.new(TokenType.ANNOTATION, value, _line, start_col))


## Scan a number literal.
func _scan_number() -> void:
	var start_col := _column
	var value := ""

	if _source[_pos] == "-":
		value += _advance()

	while _pos < _source.length():
		var c := _source[_pos]
		if c.is_valid_int() or c == "." or c == "x" or c == "b" or c == "_":
			value += _advance()
		elif c in ["e", "E"] and value.is_valid_float():
			value += _advance()
			if _pos < _source.length() and _source[_pos] in ["+", "-"]:
				value += _advance()
		else:
			break

	_tokens.append(Token.new(TokenType.NUMBER, value, _line, start_col))


## Scan an identifier or keyword.
func _scan_identifier() -> void:
	var start_col := _column
	var value := ""

	while _pos < _source.length():
		var c := _source[_pos]
		if c == "_" or c.is_valid_int() or c.to_upper() != c.to_lower():
			value += _advance()
		else:
			break

	var type := _keyword_type(value)
	_tokens.append(Token.new(type, value, _line, start_col))


## Keyword to token type mapping.
const KEYWORD_MAP := {
	"class": TokenType.CLASS,
	"func": TokenType.FUNC,
	"signal": TokenType.SIGNAL,
	"enum": TokenType.ENUM,
	"const": TokenType.CONST,
	"if": TokenType.IF,
	"elif": TokenType.ELIF,
	"else": TokenType.ELSE,
	"for": TokenType.FOR,
	"while": TokenType.WHILE,
	"match": TokenType.MATCH,
	"when": TokenType.WHEN,
	"var": TokenType.VAR,
	"return": TokenType.RETURN,
	"break": TokenType.BREAK,
	"continue": TokenType.CONTINUE,
	"pass": TokenType.PASS,
	"await": TokenType.AWAIT,
	"yield": TokenType.YIELD,
	"assert": TokenType.ASSERT,
}


## Get token type for a keyword or identifier.
func _keyword_type(word: String) -> TokenType:
	return KEYWORD_MAP.get(word, TokenType.IDENTIFIER)


## Scan an operator or punctuation.
func _scan_operator() -> void:
	var start_col := _column
	var c := _advance()

	# Multi-character operators
	if _pos < _source.length():
		var next := _source[_pos]
		var two := c + next
		if two in ["==", "!=", "<=", ">=", "&&", "||", "->", ":=", "+=", "-=", "*=", "/="]:
			_advance()
			_tokens.append(Token.new(TokenType.OPERATOR, two, _line, start_col))
			return

	# Single character
	if c in "+-*/%=<>!&|^~":
		_tokens.append(Token.new(TokenType.OPERATOR, c, _line, start_col))
	else:
		_tokens.append(Token.new(TokenType.PUNCTUATION, c, _line, start_col))
