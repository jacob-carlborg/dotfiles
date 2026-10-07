---
name: gh-relates-to
description: Link GitHub issues with the native "relates to" relationship, and read those links. Use when asked to relate, link or connect two issues, to add a "relates to" relationship, or to find which issues an issue relates to. `gh issue` has no flag for this, so it goes through GraphQL.
---

# "Relates to" between GitHub issues

`gh issue` (2.101) only has flags for parent/sub-issue and blocked-by/blocking.
"Relates to" is GraphQL only. It links issues only, not PRs: to relate a PR, use the issue it fixes.

## Add

```sh
a=$(gh issue view <A> --repo <owner>/<repo> --json id --jq .id)
b=$(gh issue view <B> --repo <owner>/<repo> --json id --jq .id)
gh api graphql -f query='mutation($i:ID!,$r:ID!){ addRelatesTo(input:{issueId:$i, relatedIssueId:$r}){ clientMutationId } }' -f i="$a" -f r="$b"
```

One call links both ways: B shows A as well. Don't add it again from the other side.

## Remove

Same inputs, `removeRelatesTo` in place of `addRelatesTo`.

## Read

```sh
gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>"){ issue(number:<n>){ relatesTo(first:50){ totalCount nodes{ number title repository{ nameWithOwner } } } } } }'
```

Compare `totalCount` with the number of nodes to catch truncation.
