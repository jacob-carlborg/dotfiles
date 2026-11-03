#!/usr/bin/env python3
"""PreToolUse hook: block Bash commands that print a GitHub token through gh.

Blocks `gh auth token` and `gh auth status --show-token` (or `-t`); exit 2
sends stderr to the model. Cobra accepts a subcommand's flags anywhere before
it (`gh --hostname x auth token`), so instead of matching a fixed prefix, each
simple command that runs gh is checked for the subcommand words anywhere after
gh. Quoted text is one word, so `gh pr create --title "auth token"` passes;
a word that lexes into something else (quoted text) is also checked as a
command of its own, for `sh -c '...'`, down to MAX_DEPTH levels of nesting.

Past that depth, or if the hook fails on its input, it blocks only when the
raw input mentions both `gh` and `auth`, so a bug here does not block every
Bash command.

This guards against accidental use, not a determined agent: variables, command
substitution, xargs, gh aliases and scripts all get around it.
"""

import json
import os
import re
import shlex
import sys

SEPARATOR_CHARS = set(";&|()")
MAX_DEPTH = 5
GH_AUTH = re.compile(r"\bgh\b.*\bauth\b", re.DOTALL)


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


def mentions_gh_auth(text):
    return GH_AUTH.search(text) is not None


def runs_token_command(command, depth=MAX_DEPTH):
    if depth < 0:
        return mentions_gh_auth(command)
    tokens = words(command)
    if any(prints_token(gh_args(c)) for c in simple_commands(tokens)):
        return True
    # Quoted words may hold a command of their own, as in `sh -c '...'`. Only
    # a word that lexing changes can. One that lexes back to itself, such as a
    # word spaced by a non-breaking space (which shlex does not split on),
    # would recurse forever.
    return any(runs_token_command(t, depth - 1) for t in tokens if words(t) != [t])


def blocks(payload):
    try:
        command = json.loads(payload).get("tool_input", {}).get("command", "")
        return runs_token_command(command)
    except Exception:
        return mentions_gh_auth(payload)


def main():
    if blocks(sys.stdin.read()):
        print(
            "Blocked: don't print GitHub tokens. `gh auth token` and "
            "`gh auth status --show-token` are not allowed.",
            file=sys.stderr,
        )
        sys.exit(2)


main()
