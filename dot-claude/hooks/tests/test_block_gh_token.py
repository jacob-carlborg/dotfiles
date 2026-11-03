"""Tests for block-gh-token.py, run as Claude Code runs it: JSON on stdin.

Run with: python3 -m unittest discover dot-claude/hooks/tests
"""

import json
import pathlib
import shlex
import subprocess
import sys
import unittest

HOOK = pathlib.Path(__file__).resolve().parent.parent / "block-gh-token.py"
BLOCKED = 2

# Whitespace to Python's `re` (`\s`) but not to `shlex`, which splits only on
# ' \t\r\n'. Escaped here so no literal non-breaking space sits in the source.
NON_SHLEX_WHITESPACE = [" ", " ", "　", "\x0b", "\x0c", "\x1c", "\x85"]


def run_hook(command):
    return run_hook_on(json.dumps({"tool_input": {"command": command}}))


def run_hook_on(payload):
    return subprocess.run(
        [sys.executable, str(HOOK)], input=payload, capture_output=True, text=True, timeout=10
    )


def nested_sh(command, depth):
    for _ in range(depth):
        command = "sh -c " + shlex.quote(command)
    return command


class BlockGhTokenTest(unittest.TestCase):
    def assert_blocked(self, command):
        result = run_hook(command)
        self.assertEqual(BLOCKED, result.returncode, result.stderr)
        self.assertIn("Blocked", result.stderr)

    def assert_allowed(self, command):
        result = run_hook(command)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_blocks_gh_auth_token(self):
        self.assert_blocked("gh auth token")

    def test_blocks_gh_auth_token_after_global_flag(self):
        self.assert_blocked("gh --hostname x auth token")

    def test_blocks_gh_auth_status_with_short_flag(self):
        self.assert_blocked("gh auth status -t")

    def test_blocks_gh_auth_status_with_long_flag(self):
        self.assert_blocked("gh auth status --show-token")

    def test_blocks_gh_auth_token_in_single_quoted_sh_c(self):
        self.assert_blocked("sh -c 'gh auth token'")

    def test_blocks_gh_auth_token_in_double_quoted_bash_c(self):
        self.assert_blocked('bash -c "gh auth token"')

    def test_blocks_gh_auth_token_nested_a_few_levels(self):
        self.assert_blocked(nested_sh("gh auth token", 4))

    def test_blocks_gh_auth_token_after_a_non_breaking_space(self):
        self.assert_blocked("echo ' x y' && gh auth token")

    def test_allows_auth_token_as_quoted_title(self):
        self.assert_allowed('gh pr create --title "auth token"')

    def test_allows_quoted_non_shlex_whitespace(self):
        for space in NON_SHLEX_WHITESPACE:
            with self.subTest(space=repr(space)):
                self.assert_allowed(f"ruby -e 'p \" 718{space}92 \".gsub(/[[:space:]]/, \"\")'")

    def test_allows_heredoc_with_a_non_breaking_space(self):
        self.assert_allowed(
            "cat > spec.rb <<'EOF'\n"
            "it { expect(parse(\" 718 92 \")).to eq(71892) }\n"
            "EOF\n"
            "python3 - <<'EOF'\n"
            "print(\"it's \\\"quoted\\\" 'twice'\")\n"
            "EOF"
        )

    def test_allows_deeply_nested_harmless_command(self):
        self.assert_allowed(nested_sh("echo 'a b'", 7))

    def test_blocks_deeply_nested_gh_auth_token(self):
        self.assert_blocked(nested_sh("gh auth token", 7))

    def test_blocks_unreadable_input_that_mentions_gh_auth(self):
        result = run_hook_on('{"tool_input": {"command": "gh auth token"')
        self.assertEqual(BLOCKED, result.returncode, result.stderr)

    def test_allows_unreadable_input_that_does_not_mention_gh_auth(self):
        result = run_hook_on('{"tool_input": {"command": "ls -la"')
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
