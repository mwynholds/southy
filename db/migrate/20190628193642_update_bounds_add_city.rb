class UpdateBoundsAddCity < ActiveRecord::Migration[5.2]
  def change
    add_column :bounds, :departure_city,  :string
    add_column :bounds, :departure_state, :string
    add_column :bounds, :arrival_city,    :string
    add_column :bounds, :arrival_state,   :string
  end
end
