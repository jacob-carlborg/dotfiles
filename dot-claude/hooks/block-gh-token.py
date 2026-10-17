#!/usr/bin/env python3
"""PreToolUse hook: block Bash commands that print a GitHub token through gh.

Blocks `gh auth token` and `gh auth status --show-token` (or `-t`); exit 2
sends stderr to the model. Cobra accepts a subcommand's flags anywhere before
it (`gh --hostname x auth token`), so instead of matching a fixed prefix, each
simple command that runs gh is checked for the subcommand words anywhere after
gh. Quoted text is one word, so `gh pr create --title "auth token"` passes;
quoted text is also checked as a command of its own, for `sh -c '...'`.

This guards against accidental use, not a determined agent: variables, command
substitution, xargs, gh aliases and scripts all get around it.
"""

import json
import os
import re
import shlex
import sys

SEPARATOR_CHARS = set(";&|()")


def words(command):
    lexer = shlex.shlex(command.replace("\n", ";"), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        # Unbalanced quotes: fall back to splitting on whitespace and dropping
        # quotes, which errs towards blocking.
        return [w.strip("'\"") for w in re.findall(r"[^\s;&|()]+|[;&|()]+", command)]


def simple_commands(tokens):
    current = []
    for token in tokens:
        if set(token) <= SEPARATOR_CHARS:
            yield current
            current = []
        else:
            current.append(token)
    yield current


def gh_args(command):
    for index, word in enumerate(command):
        if os.path.basename(word) == "gh":
            return command[index + 1:]
    return []


def shows_token(arg):
    name = arg.split("=", 1)[0]
    if name.startswith("--"):
        return name == "--show-token"
    return name.startswith("-") and "t" in name


def prints_token(args):
    if "auth" not in args:
        return False
    return "token" in args or ("status" in args and any(map(shows_token, args)))


def runs_token_command(command):
    tokens = words(command)
    if any(prints_token(gh_args(c)) for c in simple_commands(tokens)):
        return True
    # Quoted words may hold a command of their own, as in `sh -c '...'`.
    return any(runs_token_command(t) for t in tokens if re.search(r"\s", t))


def main():
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    if runs_token_command(command):
        print(
            "Blocked: don't print GitHub tokens. `gh auth token` and "
            "`gh auth status --show-token` are not allowed.",
            file=sys.stderr,
        )
        sys.exit(2)


main()
