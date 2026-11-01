# Fun Library

A single-tenant (for now) personal reading tracker: users look up books by ISBN, add them to their reading list, log reading sessions against them, and track progress toward reading goals.

## Language

**Book**:
Pure bibliographic catalog data for a single ISBN — title, authors, cover, page count, publish year, plus the external source it was fetched from. Tenant-agnostic; not tied to any one user's reading state. Deduplicated by `isbn` — looking up an ISBN that's already in the catalog reuses the existing `Book` rather than creating a new one.
_Avoid_: Title, volume

**Reading list**:
The set of `ReadingListEntry` records belonging to a user. "Adding a book to the reading list" means creating a `ReadingListEntry` that links a user to a `Book`.
_Avoid_: Library (ambiguous with the `Library` context), collection

**Reading list entry**:
A user's relationship to a specific `Book` — carries `status`, `started_at`, `finished_at`. This is where per-user reading state lives, deliberately separated from `Book` so the same catalog entry can eventually be shared across tenants. One entry per `(user, book)` pair — re-reads (multiple entries for the same book) are a deferred concept, not yet supported.
_Avoid_: UserBook, LibraryEntry

**Start date** / **Finish date** (of a reading list entry):
The calendar days, in the app's timezone, the reader started and finished the book. Set automatically from the session that triggered them: the start date is the day the first session started, the finish date is the day the finishing session ended. Either can be edited by hand (e.g. logging a book read before using the app), and the edited value is authoritative.
_Avoid_: Started/finished timestamp (they are days, not instants)

**Status** (of a reading list entry):
Where a user is with a book: `want_to`, `reading`, `read`, `stopped`, `unfinished`. Lives on `ReadingListEntry`, never on `Book`.

**Reading span** (of a reading list entry):
The range of calendar days a book's pages-per-day chart covers. Starts on the start date; ends on the finish date for a `read` book, today for a `reading` book, and the book's last reading day (or the start date, if none) for a `stopped` or `unfinished` book. No start date means no reading span. Sessions outside the span still count everywhere else, they are just not charted.
_Avoid_: Chart window (the window is the 7 visible days inside the span), reading period

**Lookup** (BookLookup context):
The read-only act of fetching bibliographic data for an ISBN from an external source (Google Books) without persisting anything. Returns a preview the caller can inspect before deciding to add it.
_Avoid_: Search, fetch (as a domain term — "fetch" is fine as implementation detail, not as the name of the operation)

**Confirm** (adding to the reading list):
The second step of adding a book: given (possibly user-edited) attributes from a prior lookup, find-or-create the `Book` and create a `ReadingListEntry` for the user. This is the only step that persists data.

**Session highlight**:
A short passage or reflection, up to one paragraph, a reader captures from a book against a finished `Session`. Optional, and unlike the rest of a finished session's data, editable afterward through its own route.
_Avoid_: Note, comment, log entry

**Daily highlight**:
One session highlight of at most 120 characters, chosen at random once per calendar day in the app's timezone, cycling through every eligible highlight before any repeats. There is none on a day with no eligible highlights.
_Avoid_: Quote of the day, featured highlight

**Open session**:
A session that has started but not yet been finished. A reader has at most one at a time, across all reading list entries (see ADR 0005).
_Avoid_: Active session, in-progress session

**Current page** (of a reading list entry):
The end page of the entry's latest session, or its start page if that session is still open. An entry with no sessions has no current page.
_Avoid_: Bookmark, last page

**Pace** (of a reading list entry):
Pages per day, averaged over the last 7 days; when that is zero, pages read so far divided by days since the start date. No pace when neither yields a positive number.
_Avoid_: Speed, rate

**Days left** (of a reading list entry):
Remaining pages divided by pace, rounded up. Undefined without a page count or a pace.
_Avoid_: ETA, finish estimate

**Reading day**:
A calendar day, in the app's timezone, on which at least one finished session ended having advanced pages (end page after start page). Reading several books on the same day still makes one reading day.
_Avoid_: Active day, streak day

**Current streak**:
The number of consecutive reading days ending today, or ending yesterday if today has no reading yet. It is user-level, not per-book.
_Avoid_: Days streak

**Streak record**:
The longest run of consecutive reading days in the user's whole reading history. It is always derived from the sessions as they exist now, so editing or deleting sessions can lower it.
_Avoid_: Best streak, high score, max streak

**Goal**:
A reader's target number of books to finish within one goal period. A reader has at most one goal of each type (annual, monthly) per goal period.
_Avoid_: Challenge, target (as the name of the whole thing — "target" is the number of books)

**Goal period**:
The calendar span a goal covers: one calendar year for an annual goal, one calendar month for a monthly goal, in the app's timezone. It is fixed by the goal's type and its year or month, never by arbitrary dates.
_Avoid_: Range, window, timeframe

**Current goal** / **Upcoming goal**:
A current goal's goal period contains today; an upcoming goal's period starts after today. Goals can only be created for current or upcoming periods, and until they close their target can be changed and they can be deleted. A goal's type and period never change; moving a goal means deleting it and creating another.
_Avoid_: Active goal, open goal (open is reserved for sessions), future goal

**Books finished** (toward a goal):
The reader's reading list entries with status `read` whose finish date falls within the goal period. Always derived from the reading list as it is now, so editing a finish date can change a past goal's count.
_Avoid_: Books read, completed books

**Carried over** (in a goal period):
A book the reader had reading days on within a goal period without finishing it there, and kept reading in a later period. Shown on that goal alongside its books finished, but never counted toward it. In the period where the book's reading ends, it shows its outcome instead: finished there, or its entry status (reading, on hold, did not finish).
_Avoid_: Unfinished (that is an entry status — the reader gave up), not finished, in progress

**Closed goal**:
A goal whose goal period has ended — today, in the app's timezone, is after its last day. Closing is not an event and nothing is stored; a goal is closed purely by the calendar. A closed goal is locked: its target cannot be changed and it cannot be deleted, though its books finished can still move.
_Avoid_: Finished goal, expired goal, archived goal

**Achieved** / **Missed** (of a closed goal):
A closed goal is achieved when its books finished reached its target, otherwise missed. Like books finished, this is derived, never frozen.
_Avoid_: Completed / failed

**Goal history**:
The reader's closed goals, newest period first, annual and monthly together. Periods without a goal don't appear.
_Avoid_: Archive, log

## Reading (context)

Owns per-user reading state and progress: `ReadingListEntry`, `Session`, `Goal`. A `Session` references a `ReadingListEntry`, not a `Book` directly — progress belongs to a specific reader's relationship with a book, not to the shared catalog entry. A `Goal` belongs to the reader and is measured against their reading list entries finished within its goal period.

## Library (context)

Owns the shared book catalog: `Book` CRUD and find-or-create-by-ISBN. Does not know about users, status, or reading state.

## BookLookup (context)

Standalone adapter context for external bibliographic lookups. Talks to Google Books via `Req`. Returns normalized data or a typed error (`:not_found`, `:isbn_invalid`, `:external_api_error`); persists nothing itself.
