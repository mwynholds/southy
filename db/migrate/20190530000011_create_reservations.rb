class CreateReservations < ActiveRecord::Migration[5.2]
  def change
    create_table :reservations do |t|
      t.string :confirmation_number, null: false
      t.string :origin_code,         null: false
      t.string :destination_code,    null: false
      t.string :email,               null: true

      t.timestamps
    end
  end
end
