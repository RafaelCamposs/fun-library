# The reading span bounds the book chart, in the app's timezone

The book detail pages-per-day chart used to show a fixed "last 7 days ending today", so a finished book showed only empty days. We now bound the chart by the entry's **reading span**, computed in the backend and returned by `GET /api/reading_list_entries/:id/stats` as `reading_span: {start_date, end_date}` (or `null`), with `pages_per_day` filtered to it. The client only lays the span out. All days are calendar days in the app's timezone (`:utc_offset_minutes`), never UTC.

## Business rules

- **Start of span** is the entry's start date. No start date means no span (`null`) and no chart. The client shows its "not started" state. A hand-logged `read` entry with only a finish date gets no chart either; we don't invent a start date.
- **End of span** depends on status:
  - `read` ends on the finish date.
  - `reading` ends today.
  - `stopped` / `unfinished` end on the book's last reading day: the most recent finished session that advanced pages, the same rule as **Reading day**. If there is none, the span ends on the start date. There is no "stopped date" field, and ending on today would open a dropped book on empty days.
- **The entry dates are authoritative.** Sessions that fall outside the span (only possible through manual edits) are left off the chart. They still count toward reading days, streaks, and percent complete. `pages_per_day` stays sparse (only days with reading); the client fills the other days inside the span with zero.
- **`days_elapsed` is unchanged** (finish date or today, minus start date). It answers "how long since I picked this up", not "how long the span is".

## Chart display (client)

- Show 7 columns at a time. The initial window is the 7 days ending on the span's end date, and you can scroll left down to the start date, never earlier and never past the end date.
- If the span is shorter than 7 days, the window still ends on the end date. Columns before the start date are blank placeholders, not `0`, so they don't read as days without reading.
- Columns are labelled with the date as `01 Nov`, not the weekday, because weekdays repeat once you can scroll back.

## Entry dates follow their sessions

The start and finish dates used to be stamped with `Date.utc_today()` at request time. Finishing a book after 21:00 in Brasília (UTC-3) therefore gave it tomorrow's date, while its session's pages were charted on today. The dates now come from the session that triggered them, converted to the app's timezone: the start date is the local day of the first session's `started_at`, and the finish date is the local day of the finishing session's `ended_at`. A late-logged session no longer moves the date to the day it was logged. Hand-edited dates stay authoritative. The client's notion of "today" must also be the app's day, not the UTC date.

A one-off data migration corrects existing entries. It only touches entries whose date equals the UTC day of the relevant session but not its app-timezone day, so other mismatches are treated as manual edits and left alone.

## Considered options

- **Session dates as the span (first to last reading day), or the entry dates widened to include outlying sessions.** Rejected once the entry dates were made to follow their sessions. A single authoritative source is simpler, and manual edits are deliberate.
- **Window logic in the client.** Rejected: the status rules, the last reading day, and the app-timezone "today" need data and configuration the backend already owns, and `librarian-cli` can reuse the result.
- **Opening a finished book on its start date, or fitting the whole span.** Rejected in favour of a consistent "open on the most recent activity" across all statuses.
