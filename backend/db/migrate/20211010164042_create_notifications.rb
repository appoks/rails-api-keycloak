class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications do |t|
      t.text :message
      t.integer :kind
      t.boolean :read

      t.timestamps
    end
  end
end
