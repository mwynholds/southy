class CreateSources < ActiveRecord::Migration[5.2]
  def change
    create_table :sources do |t|
      t.jsonb :json, null: false

      t.belongs_to :reservation, index: true

      t.timestamps
    end
  end
end
