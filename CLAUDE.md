# Working here with Claude

Read the README first; this file holds only the rules the code cannot say.

## Work belongs to a ToDo task

Tech-team work is tracked on the ToDo board in FF Tools (`https://tools.foodies-first.com/t/tasks`).
When starting a piece of work, list the person's open tasks —
`curl -s -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://tools.foodies-first.com/api/dev/tasks`
(their own and those shared with them; read only) — propose the one that fits and confirm it in one
line; when none fits, ask once, and if there is none, say so and carry on. The branch is
`<person>/t-<id>-<topic>`, the pull request title ends with `(t-<id>)`, and the id goes nowhere else —
the board links every commit on that branch and the squash merge on `main` by that id, whoever's
email is on the commit. Never use an id the person did not confirm (Edouard, 2026-11-02).
