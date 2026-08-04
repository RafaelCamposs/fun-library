defmodule FunLibrary.Repo do
  use Ecto.Repo,
    otp_app: :fun_library,
    adapter: Ecto.Adapters.Postgres
end
