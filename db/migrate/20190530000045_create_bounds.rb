class CreateBounds < ActiveRecord::Migration[5.2]
  def change
    create_table :bounds do |t|
      t.column     :departure_time, "timestamp with time zone", null: false
      t.string     :departure_code, null: false

      t.column     :arrival_time,   "timestamp with time zone", null: false
      t.string     :arrival_code,   null: false

      t.string     :flights,        array: true, default: []

      t.belongs_to :reservation,    index: true

      t.timestamps
    end
  end
end
