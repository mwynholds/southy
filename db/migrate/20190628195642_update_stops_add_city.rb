class UpdateStopsAddCity < ActiveRecord::Migration[5.2]
  def change
    add_column :stops, :city,  :string
    add_column :stops, :state, :string
  end
end
