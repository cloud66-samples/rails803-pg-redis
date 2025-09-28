class CreateFlowers < ActiveRecord::Migration[7.0]
  def change
    create_table :flowers do |t|
      t.string :color
      t.integer :number_of_petals
      t.timestamps
    end
  end
end 