class UpdateStopsAddPlaneChange < ActiveRecord::Migration[5.2]
  def change
    add_column :stops, :plane_change, :boolean, default: true
  end
end
