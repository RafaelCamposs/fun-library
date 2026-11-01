defmodule FunLibrary.Repo.Migrations.SnapReadingGoalsToCalendarPeriods do
  use Ecto.Migration

  # A goal now covers exactly one goal period (ADR 0006): it is stored as its
  # type plus the first day of its calendar year or month. Existing goals are
  # snapped to the period containing their period_start; where that yields
  # several goals of one type in one period for a reader, the most recently
  # updated one is kept (ties broken by the highest id).
  def up do
    execute("""
    UPDATE reading_goals
    SET period_start = date_trunc('year', period_start)::date
    WHERE period_type = 'annual'
    """)

    execute("""
    UPDATE reading_goals
    SET period_start = date_trunc('month', period_start)::date
    WHERE period_type = 'monthly'
    """)

    execute("""
    DELETE FROM reading_goals AS g
    USING reading_goals AS newer
    WHERE newer.user_id = g.user_id
      AND newer.period_type = g.period_type
      AND newer.period_start = g.period_start
      AND (newer.updated_at > g.updated_at
           OR (newer.updated_at = g.updated_at AND newer.id > g.id))
    """)

    alter table(:reading_goals) do
      remove :period_end
    end

    create unique_index(:reading_goals, [:user_id, :period_type, :period_start])
  end

  # The deduplicated goals can't be restored; period_end is re-derived from
  # the (already snapped) period.
  def down do
    drop unique_index(:reading_goals, [:user_id, :period_type, :period_start])

    alter table(:reading_goals) do
      add :period_end, :date
    end

    execute("""
    UPDATE reading_goals
    SET period_end = CASE period_type
      WHEN 'annual' THEN (period_start + interval '1 year' - interval '1 day')::date
      ELSE (period_start + interval '1 month' - interval '1 day')::date
    END
    """)
  end
end
