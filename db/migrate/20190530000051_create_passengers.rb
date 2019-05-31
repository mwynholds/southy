class CreatePassengers < ActiveRecord::Migration[5.2]
  def change
    create_table :passengers do |t|
      t.string     :name,        null: false

      t.belongs_to :reservation, index: true

      t.timestamps
    end
  end
end
