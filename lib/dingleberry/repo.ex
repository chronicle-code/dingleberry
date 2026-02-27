defmodule Dingleberry.Repo do
  use Ecto.Repo,
    otp_app: :dingleberry,
    adapter: Ecto.Adapters.SQLite3
end
