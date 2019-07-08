class UpdateBoundsRenameBoundType < ActiveRecord::Migration[5.2]
  def change
    rename_column :bounds, :boundType, :bound_type
  end
end
