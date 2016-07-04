class ModifyProjectsAddStarred < ActiveRecord::Migration
    def up
        add_column :projects, :starred, :boolean
    end

    def down
        remove_column :projects, :starred
    end
end
