class CreateSeats < ActiveRecord::Migration[5.2]
  def change
    create_table :seats do |t|
      t.string     :group,     null: false
      t.string     :position,  null: false
      t.string     :flight,    null: false

      t.belongs_to :bound,     index: true
      t.belongs_to :passenger, index: true

      t.timestamps
    end
  end
end
