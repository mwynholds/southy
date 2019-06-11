class DropSources < ActiveRecord::Migration[5.2]
  def change
    drop_table :sources
  end
end
