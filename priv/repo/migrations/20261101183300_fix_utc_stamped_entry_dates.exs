defmodule FunLibrary.Repo.Migrations.FixUtcStampedEntryDates do
  use Ecto.Migration

  # Entry start/finish dates used to be stamped with the UTC date, so reading
  # late in the evening (in the app's timezone) dated them a day late. Only
  # dates that match the triggering session's UTC day but not its app-timezone
  # day are corrected; anything else is treated as a manual edit. See ADR 0003.
  def up do
    offset = Application.fetch_env!(:fun_library, :utc_offset_minutes)

    execute("""
    UPDATE reading_list_entries AS e
    SET finished_at = (s.ended_at + make_interval(mins => #{offset}))::date
    FROM (
      SELECT DISTINCT ON (reading_list_entry_id) reading_list_entry_id, ended_at
      FROM reading_sessions
      WHERE ended_at IS NOT NULL
      ORDER BY reading_list_entry_id, ended_at DESC
    ) AS s
    WHERE s.reading_list_entry_id = e.id
      AND e.finished_at = s.ended_at::date
      AND e.finished_at <> (s.ended_at + make_interval(mins => #{offset}))::date
    """)

    execute("""
    UPDATE reading_list_entries AS e
    SET started_at = (s.started_at + make_interval(mins => #{offset}))::date
    FROM (
      SELECT DISTINCT ON (reading_list_entry_id) reading_list_entry_id, started_at
      FROM reading_sessions
      ORDER BY reading_list_entry_id, started_at ASC
    ) AS s
    WHERE s.reading_list_entry_id = e.id
      AND e.started_at = s.started_at::date
      AND e.started_at <> (s.started_at + make_interval(mins => #{offset}))::date
    """)
  end

  # The corrected dates can't be told apart from correct ones afterwards.
  def down, do: :ok
end
