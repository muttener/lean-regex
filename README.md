# lean-regex

A formally verified regular expression engine for the Lean programming language.

## Overview

lean-regex provides a robust, formally verified implementation of regular expressions for Lean 4. The library implements two distinct matching algorithms (a backtracker and a virtual machine), both with complete mathematical proofs of their correctness.

### Key Features

- **Formally Verified**: Both matching algorithms (backtracker and VM) are mathematically proven to correctly implement the semantics of regular expressions
- **Real-World Regex Features**: Support for capture groups, character classes, substring matching, and more
- **Two Matching Engines**: Choose between a backtracker or virtual machine implementation, both provably correct
- **Simple API**: Clean, easy-to-use interface for common regex operations

## Installation

Add lean-regex to your Lean project by adding the following to your `lakefile.toml`:

```toml
[[require]]
name = "Regex"
git = "https://github.com/pandaman64/lean-regex"
rev = "v4.20.0"
subDir = "regex"
```

or

```lean
require Regex from git "https://github.com/pandaman64/lean-regex.git" @ "v4.20.0" / "regex"
```

to your `lakefile.lean`.

## Usage

```lean
import Regex

-- Create a regex at compile-time using re! syntax
def dateRegexExample := re! r"\d{4}-\d{2}-\d{2}"

-- Find and return matches (and their positions as components of each `Substring`)
def allMatches := dateRegexExample.findAll
  "2025-05-24: Something happened\\n2025-05-26: Another thing happened"

-- #["2025-05-24".toSubstring, "2025-05-26".toSubstring]
#eval allMatches

-- #[{ byteIdx := 0 }, { byteIdx := 32 }]
#eval allMatches.map (·.startPos)

-- Capture groups
def groupRegexExample := re! r"(a+)(b*)"

def captures := groupRegexExample.capture "aaabb"

/-
Returns captured groups: group 0 = whole match, group 1 = "aaa", group 2 = "bb":

some {
  haystack := "aaabb",
  buffer := #[
    some { byteIdx := 0 }, some { byteIdx := 5 },
    some { byteIdx := 0 }, some { byteIdx := 3 },
    some { byteIdx := 3 }, some { byteIdx := 5 }
  ]
}
-/
#eval captures

-- Additional utility methods are available
def utilityRegexExample := re! r"a+"

def haystack := "a1aa2aaa3"

-- some "a"
#eval utilityRegexExample.extract haystack

-- #["a", "aa", "aaa"]
#eval utilityRegexExample.extractAll haystack

-- true
#eval utilityRegexExample.test haystack

-- 3
#eval utilityRegexExample.count haystack

/-
Splits a string using regex matches as breakpoints:

#["", "1", "2", "3"]

Note the empty substring due to the match "a" at the beginning of the input:
"a1aa2aaa3" = "" ++ "a" ++ "1" ++ "aa" ++ "2" ++ "aaa" ++ "3"
-/
#eval utilityRegexExample.split haystack
```

For more details, please check [the API reference](https://pandaman64.github.io/lean-regex/Regex.html).

## Formal Verification

The library's correctness is formally verified through mathematical proofs in Lean 4. This ensures that:

1. **Soundness**: When the engine reports a match, it correctly follows the formal semantics of regular expressions
2. **Completeness**: When the engine reports no match, there truly is no match according to the formal semantics
3. **Capture Correctness**: Capture groups correctly identify the matched substrings

## Contributing

Contributions are welcome! Please start by creating an issue to discuss your proposed changes before submitting a Pull Request.

## License

This project is licensed under the Apache License 2.0.

