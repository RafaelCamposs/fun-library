---
status: accepted
---

# One open session per reader, not per entry

`start_session` currently refuses a second **open session** only on the same reading list entry (`:session_already_open`), so a reader can have sessions open on several books at once. We are tightening this to at most one open session per reader across all entries. Nobody reads two books in the same sitting, so a second open session is almost always a forgotten one, and forgotten sessions inflate session minutes. The dashboard launchpad also assumes there is a single open session to show with its timer and FINISH action. Starting a session while another entry has one open fails with an error that identifies the open session, and the client tells the reader to finish that book first.

## Considered options

- **Allow several open sessions, and have the dashboard show the most recently started one.** Rejected: it keeps the forgotten-session problem and makes the launchpad ambiguous.
- **Starting a new session auto-closes the open one.** Rejected: closing needs an end page only the reader knows. It would either hide a modal inside the one-tap Resume action or record a wrong end page.

## Consequences

- Existing data may already contain several open sessions for one user. These must be resolved before the rule is enforced in the database (a partial unique index on `user_id` where `ended_at` is null needs the user on the session or a join through the entry). Otherwise the rule is enforced in `start_session` only.
- Forgotten sessions get no special handling (no stale threshold, no auto-close). A session left open overnight still records its full duration, and that duration counts toward minutes stats.
