class AddLocationToMenuItems < ActiveRecord::Migration[8.1]
  def change
    add_column :menu_items, :location, :string, default: 'navbar', null: false
    add_index :menu_items, :location
  end
end
