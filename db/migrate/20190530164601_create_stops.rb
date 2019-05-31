class CreateStops < ActiveRecord::Migration[5.2]
  def change
    create_table :stops do |t|
      t.string     :code,           null: false
      t.timestamp  :arrival_time,   null: false
      t.timestamp  :departure_time, null: false

      t.belongs_to :bound,          index: true

      t.timestamps
    end
  end
end
