defmodule Pointex.Repo.Migrations.AddActualResultsAttributesToSong do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    rename table(:songs), :final_place, to: :actual_place_in_final

    alter table(:songs) do
      modify :actual_place_in_final, :bigint
      add :went_to_final, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:songs) do
      remove :went_to_final
      modify :final_place, :bigint
    end

    rename table(:songs), :actual_place_in_final, to: :final_place
  end
end
