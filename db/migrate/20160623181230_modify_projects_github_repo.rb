class ModifyProjectsGithubRepo < ActiveRecord::Migration
    def up
        add_column :projects, :github_repo, :string
    end

    def down
        remove_column :projects, :github_repo
    end
end
