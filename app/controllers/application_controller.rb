require_relative "../../config/environment"

require_relative "../models/project.rb"

class ApplicationController < Sinatra::Base

    enable :sessions
    set :session_secret, 'secret secret cookie' # FIXME: make an actual secret

    set :views, "app/views"
    set :public_folder, "public"

    before do 
        @CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
        @CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']
    end

    after do
        if not @CLIENT_ID or not @CLIENT_SECRET
            puts "****** GITHUB API CREDENTIALS NOT SET ******"
            puts "Create an application at https://github.com/settings/applications."
            puts "Then, set the environment variables GH_BASIC_CLIENT_ID and GH_BASIC_SECRET_ID."
            response.body = "GitHub API credentials aren't set - look at the console for more information."
        end
    end

    helpers do
        def h(text)
            Rack::Utils.escape_html(text)
        end

        def get_github_url(client_id, client_secret)
            return "https://github.com/login/oauth/authorize?scope=user:email&client_id=" + client_id
        end
    end

    get "/" do
        erb :index, :layout => :layout, locals: {projects: Project.order(created_at: :desc).where(approved: true)}
    end

    get "/submit" do
        erb :submit, :layout => :layout
    end

    post "/submit" do
        if not (params[:name] and params[:authors] and params[:url] and params[:description])
            return "All fields are required."
        end
        project = Project.new({
            :name => params[:name],
            :authors => params[:authors],
            :url => params[:url],
            :description => params[:description],
            :approved => false
        })
        project.save
        "Submitted!"
    end

end
