# Working here with Claude

Read the README first; this file holds only the rules the code cannot say.

## Work belongs to a ToDo task

Tech-team work is tracked on the ToDo board in FF Tools (`https://tools.foodies-first.com/t/tasks`).
When starting a piece of work, list the person's open tasks —
`curl -s -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://tools.foodies-first.com/api/dev/tasks`
(their own and those shared with them; read only) — propose the one that fits and confirm it in one line; when none fits, offer to make one —
`curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" -H "content-type: application/json" -d '{"title":"<title>","repo":"<owner/name>"}' https://tools.foodies-first.com/api/dev/tasks`
answers with the id — a good task is what the list's `guide` says: a title under 60 characters
that says what, not how; then PATCH a `description` of two or three lines (what, why, what done
looks like); one label — and the first push on its branch links the repository; the task belongs to
the gcloud account the laptop signs with, and when that is the shared `tech@`, add the header
`x-ff-as: <the address Claude Code is signed in with>` so it is the person's — and if the person
wants none, say so and carry on. When the person asks to move a task to Blocked (or any status), label it or
describe it, `PATCH` the same URL with the id and `{"status":"blocked","waitingOn":"…"}`,
`{"addLabels":["KOS"]}` or `{"description":"…"}`; never on your own. The branch is
`<person>/t-<id>-<topic>`, the pull request title ends with `(t-<id>)`, and the id goes nowhere else —
the board links every commit on that branch and the squash merge on `main` by that id, whoever's
email is on the commit. Never use an id the person did not confirm (Edouard, 2026-11-02).
