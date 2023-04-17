defmodule Boom.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:logged_out_session_ids, primary_key: false) do
      add(:session_id, :binary, null: false, primary_key: true)
      timestamps(updated_at: false)
    end
  end
end
