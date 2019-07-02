class UpdateBoundsAddType < ActiveRecord::Migration[5.2]
  def change
    add_column :bounds, :boundType, :string
  end
end
