require_relative "../../config/environment"

require_relative "../models/project.rb"

class ApplicationController < Sinatra::Base

    enable :sessions
    set :session_secret, 'secret secret cookie' # FIXME: make an actual secret

    set :views, "app/views"
    set :public_folder, "public"

    helpers do
        def h(text)
            Rack::Utils.escape_html(text)
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
