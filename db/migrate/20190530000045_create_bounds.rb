class CreateBounds < ActiveRecord::Migration[5.2]
  def change
    create_table :bounds do |t|
      t.timestamp  :departure_time, null: false
      t.string     :departure_code, null: false

      t.timestamp  :arrival_time,   null: false
      t.string     :arrival_code,   null: false

      t.string     :flights,        array: true, default: []

      t.belongs_to :reservation,    index: true

      t.timestamps
    end
  end
end
