class UpdateReservationsAddCreatedBy < ActiveRecord::Migration[5.2]
  def change
    add_column :reservations, :created_by, :string
  end
end
