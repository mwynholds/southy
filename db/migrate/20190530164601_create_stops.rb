class CreateStops < ActiveRecord::Migration[5.2]
  def change
    create_table :stops do |t|
      t.string     :code,           null: false
      t.column     :arrival_time,   "timestamp with time zone", null: false
      t.column     :departure_time, "timestamp with time zone", null: false

      t.belongs_to :bound,          index: true

      t.timestamps
    end
  end
end
