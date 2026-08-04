# Split `Book` (catalog) from `ReadingListEntry` (per-user state)

The app is single-tenant today, so `books.status/started_at/finished_at` could have stayed on `Book` — one table would have worked fine for now. We split them anyway, in advance of an intended future migration to multi-tenancy: `Book` becomes pure, tenant-agnostic bibliographic data deduplicated by ISBN, while `ReadingListEntry` (new, in the `Reading` context) holds `user_id`, `status`, `started_at`, `finished_at`. `Session` and `Goal` were repointed from `Book` to `ReadingListEntry` for the same reason — progress belongs to a reader's relationship with a book, not to the shared catalog row.

Considered keeping everything on `Book` and deferring the split until multi-tenancy actually arrives; rejected because retrofitting this split later means a data migration across `books`, `reading_sessions`, and `reading_goals` simultaneously, versus doing it now while the app is pre-launch with no data to preserve.
