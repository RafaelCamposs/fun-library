# Replace `reading_progress` with `reading_sessions`

We removed the `reading_progress` schema/table (a single running progress value per book) and replaced it with `reading_sessions` — discrete start/end page and timestamp records, one row per reading sitting. This was necessary to support the pages-per-day stats series (`GET /api/books/:id/stats`): a single mutable progress value can't reconstruct history, whereas sessions naturally bucket by the day they ended.

Two rules fell out of this and are easy to get wrong if reintroduced from scratch: only one open session (`ended_at == nil`) is allowed per book at a time — starting a new one while another is open is rejected, forcing the client to finish the open session first; and a session's pages are attributed entirely to the calendar day of `ended_at`, with no splitting across a multi-day span, even though a session can technically start on one day and end on another.

Considered splitting a session's pages proportionally across the days it spans; rejected as unnecessary complexity for a personal single-tenant tracker with no proven need for that precision.
