require_relative "../../config/environment"

require_relative "../models/project.rb"

require 'rest-client'

class ApplicationController < Sinatra::Base

    enable :sessions
    set :session_secret, 'secret secret cookie' # FIXME: make an actual secret

    set :views, "app/views"
    set :public_folder, "public"

    before do
        @CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
        @CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']

        # yes, this is dumb, but it works and I don't want to deal with activerecord so too bad
        @admins = ["thatoddmailbox", "carsonlevine"]
    end

    after do
        if not @CLIENT_ID or not @CLIENT_SECRET
            puts "****** GITHUB API CREDENTIALS NOT SET ******"
            puts "Create an application at https://github.com/settings/developers."
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

        def get_screenshot_url(id, url)
            if not File.exists?("./public/screenshots/" + id.to_s + ".png")
                IO.popen(["phantomjs", "./phantom_screenshot.js", id.to_s, url]) do |io|
                    while true
                        output = io.gets
                        if output
                            puts "[phantomjs] " + output
                        else
                            break
                        end
                    end
                end
            end
            return "screenshots/" + id.to_s + ".png"
        end
    end

    get "/" do
        erb :index, :layout => :layout, locals: {projects: Project.order(created_at: :desc).where(approved: true)}
    end

    get "/logout" do
        session.clear
        redirect "/"
    end

    get "/submit" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        erb :submit, :layout => :layout
    end

    post "/submit" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if not (params[:name] and params[:authors] and params[:url] and params[:description] and params[:ghrepo])
            return "All fields are required."
        end
        ghrepo = params[:ghrepo]
        ghrepo = ghrepo.gsub("http://github.com/", "https://github.com/") # use https
        if not ghrepo.start_with?("https://github.com/")
            return "Invalid GitHub URL - make sure it starts with https://github.com!"
        end
        project = Project.new({
            :name => params[:name],
            :authors => params[:authors],
            :url => params[:url],
            :description => params[:description],
            :github_repo => ghrepo,
            :approved => false,
            :owner => session[:username]
        })
        project.save
        "Submitted!"
    end

    get "/callback" do
        # get temporary GitHub code...
        session_code = request.env['rack.request.query_hash']['code']

        # ... and POST it back to GitHub
        result = RestClient.post('https://github.com/login/oauth/access_token',
                              {:client_id => @CLIENT_ID,
                               :client_secret => @CLIENT_SECRET,
                               :code => session_code},
                               :accept => :json)

        # extract the token and granted scopes
        access_token = JSON.parse(result)['access_token']
        session[:logged_in] = true
        session[:access_token] = access_token

        auth_result = JSON.parse(RestClient.get('https://api.github.com/user',
                                        {:params => {:access_token => access_token}}))

        session[:username] = auth_result["login"]
        session[:user_id] = auth_result["id"]
        session[:avatar_url] = auth_result["avatar_url"]
        session[:is_admin] = @admins.include?(session[:username])

        redirect "/"
    end

    get "/admin" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if not session[:is_admin]
            return "You do not have access to this page. If you should, try logging out and back in again."
        end
        erb :admin, :layout => :layout, locals: {unapproved: Project.order(created_at: :desc).where(approved: false) }
    end

    get "/approve" do
        if not params[:id]
            return "Missing id parameter!"
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if not session[:is_admin]
            return "You do not have access to this page. If you should, try logging out and back in again."
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return "Invalid ID"
        end
        p.approved = true
        p.save
        redirect "/admin"
    end

    get "/edit" do
        if not params[:id]
            return "Missing id parameter!"
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return "Invalid ID"
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return "You do not have access to this page. If you should, try logging out and back in again."
        end
        erb :edit, :layout => :layout, locals: {project: p}
    end

    post "/edit" do
        if not params[:id]
            return "Missing id parameter!"
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return "Invalid ID"
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return "You do not have access to this page. If you should, try logging out and back in again."
        end
        if not (params[:name] and params[:authors] and params[:url] and params[:description])
            return "All fields are required."
        end
        p.name = params[:name]
        p.authors = params[:authors]
        p.url = params[:url]
        p.description = params[:description]
        p.approved = false
        p.save

        # this will delete the project's screenshot so it will be recreated later
        if File.exists?("public/screenshots/" + p.id.to_s + ".png")
            File.delete("public/screenshots/" + p.id.to_s + ".png")
        end

        "Done! Note that your project must be reapproved to appear on the homepage."
    end
end
