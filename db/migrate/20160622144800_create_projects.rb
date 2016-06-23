class CreateProjects < ActiveRecord::Migration
  def up
      create_table :projects do |t|
          t.integer :project_id
          t.string :name
          t.string :description
          t.string :authors
          t.string :url
          t.boolean :approved
          t.timestamps
      end
  end
  def down
      drop_table :projects
  end
end
