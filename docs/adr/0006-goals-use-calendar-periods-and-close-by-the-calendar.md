---
status: accepted
---

# Goals use calendar periods and close by the calendar

A goal used to carry a free-form `period_start` and `period_end`, with `period_type` as a label only, and had no notion of being over. We are fixing each goal to one **goal period**: a calendar year for an annual goal, a calendar month for a monthly goal, at most one per type per period. A goal is stored as its type plus the first day of its period, and `period_end` is dropped. A goal is **closed** once its period has ended. Nothing is stored for that and no job runs; it is read off the calendar in the app's timezone. Books finished and achieved/missed are always derived from the reading list as it is now, never snapshotted, the same way the streak record is derived. A closed goal is **locked**: its target cannot change and it cannot be deleted, and goals can only be created for current or upcoming periods. Only the target of an unclosed goal can change.

## Considered options

- **Keep free-form date ranges.** Rejected: history becomes a list of overlapping ranges, "monthly" stops meaning anything, and there's no single answer to "how did October go?". Custom sprints can come back later as their own goal type.
- **Store a status and freeze the result when the period ends.** Rejected: it needs a job or a close-on-read step, and frozen counts drift from the reading list when a finish date is backfilled. Live derivation matches every other stat in the app.
- **Leave closed goals editable.** Rejected: if you can lower a missed target afterwards, the history stops telling you anything.

## Consequences

- Backfilling a finish date into a past period changes that closed goal's count and can flip it between missed and achieved. This is intended.
- Past periods can't get new goals, so there is no way to record targets for years before the app was used.
- Migration snaps each existing goal to the period containing its `period_start` and, where that produces duplicates, keeps the most recently updated one. A past goal's count may shift because its range now covers exactly the calendar period.
- Goal names (client-side `localStorage` only) are dropped. The period is the goal's identity.
