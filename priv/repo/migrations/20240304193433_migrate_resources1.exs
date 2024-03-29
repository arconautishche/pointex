defmodule Pointex.Repo.Migrations.MigrateResources1 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:ash_watch_parties) do
      add :owner_id, :uuid
    end

    create table(:ash_participants, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    alter table(:ash_watch_parties) do
      modify :owner_id,
             references(:ash_participants,
               column: :id,
               name: "ash_watch_parties_owner_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end
  end

  def down do
    drop constraint(:ash_watch_parties, "ash_watch_parties_owner_id_fkey")

    alter table(:ash_watch_parties) do
      modify :owner_id, :uuid
    end

    drop table(:ash_participants)

    alter table(:ash_watch_parties) do
      remove :owner_id
    end
  end
end
