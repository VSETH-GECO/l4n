class AddDiscordIdsToModels < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :discord_role_id, :string, limit: 20
    add_column :lan_parties, :discord_server_id, :string, limit: 20
  end
end
