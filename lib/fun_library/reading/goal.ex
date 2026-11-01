defmodule FunLibrary.Reading.Goal do
  @moduledoc """
  A reader's target number of books to finish within one goal period: a
  calendar year (`:annual`) or calendar month (`:monthly`) in the app's
  timezone, stored as the type plus the first day of the period (ADR 0006).

  Whether a goal is current, upcoming or closed is read off the calendar by
  `state/2`; nothing about it is stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "reading_goals" do
    field :user_id, :integer
    field :period_type, Ecto.Enum, values: [:annual, :monthly]
    field :period_start, :date
    field :target_books, :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for a new goal. `user_id` must already be set on the struct.

  `period_start` must be the first day of a year (annual) or month
  (monthly), and the period must not have ended as of `today`.
  """
  def create_changeset(%__MODULE__{} = goal, attrs, %Date{} = today) do
    goal
    |> cast(attrs, [:period_type, :period_start, :target_books])
    |> validate_required([:user_id, :period_type, :period_start, :target_books])
    |> validate_target_books()
    |> validate_period_start_aligned()
    |> validate_period_not_ended(today)
    |> unique_constraint([:user_id, :period_type, :period_start],
      error_key: :period_start,
      message: "already has a goal of this type"
    )
  end

  @doc """
  Changeset for changing an unclosed goal: only its target can change.
  """
  def target_changeset(%__MODULE__{} = goal, attrs) do
    goal
    |> cast(attrs, [:target_books])
    |> validate_required([:target_books])
    |> validate_target_books()
  end

  @doc """
  The last day of the goal's period.
  """
  def period_end(%__MODULE__{period_type: :annual, period_start: start}),
    do: Date.new!(start.year, 12, 31)

  def period_end(%__MODULE__{period_type: :monthly, period_start: start}),
    do: Date.end_of_month(start)

  @doc """
  `:current` when the goal period contains `today`, `:upcoming` when it
  starts after it, `:closed` once it has ended.
  """
  def state(%__MODULE__{} = goal, %Date{} = today) do
    cond do
      Date.after?(goal.period_start, today) -> :upcoming
      Date.before?(period_end(goal), today) -> :closed
      true -> :current
    end
  end

  @doc """
  Whether the goal's period has ended as of `today`. A closed goal is locked.
  """
  def closed?(%__MODULE__{} = goal, %Date{} = today), do: state(goal, today) == :closed

  defp validate_target_books(changeset) do
    validate_number(changeset, :target_books, greater_than: 0)
  end

  defp validate_period_start_aligned(changeset) do
    type = get_field(changeset, :period_type)

    validate_change(changeset, :period_start, fn :period_start, start ->
      if aligned?(type, start) do
        []
      else
        [period_start: "must be the first day of a #{period_unit(type)}"]
      end
    end)
  end

  defp aligned?(:annual, %Date{month: 1, day: 1}), do: true
  defp aligned?(:monthly, %Date{day: 1}), do: true
  # Without a valid type there is nothing to align to; the type's own
  # error covers it.
  defp aligned?(nil, _start), do: true
  defp aligned?(_type, _start), do: false

  defp period_unit(:annual), do: "year"
  defp period_unit(_monthly), do: "month"

  defp validate_period_not_ended(changeset, today) do
    goal = apply_changes(changeset)

    if changeset.valid? and closed?(goal, today) do
      add_error(changeset, :period_start, "must be a current or upcoming period")
    else
      changeset
    end
  end
end
