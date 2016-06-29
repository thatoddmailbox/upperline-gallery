require_relative "../../config/environment"

require_relative "../models/project.rb"

require 'rest-client'

class ApplicationController < Sinatra::Base

    use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'secret secret cookie' # FIXME: a real secret

    # allow it to be iframed
    set :protection, :except => :frame_options

    set :logger, Logger.new(STDOUT)

    set :views, "app/views"
    set :public_folder, "public"

    before do
        @CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
        @CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']

        # yes, this is dumb, but it works and I don't want to deal with activerecord so too bad
        @admins = ["thatoddmailbox", "carsonlevine", "dfenjves"]
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
                            logger.info("[phantomjs] " + output)
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
        if params[:hacky_redirect_thing]
            redirect "http://www.upperlinecode.com/student-project-gallery"
        end
        erb :index, :layout => :layout, locals: {title: "Student Project Gallery", projects: Project.order(created_at: :desc).where(approved: true)}
    end

    get "/logout" do
        session.clear
        redirect "/"
    end

    get "/submit" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        erb :submit, :layout => :layout, locals: {title: "Submit project"}
    end


    post "/submit" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if params[:name] == "" or params[:authors] == "" or params[:url] == "" or params[:description] == ""
            return erb :error, :layout => :layout, locals: {title: "Error", error: "All fields except GitHub repository are required."}
        end
        ghrepo = params[:ghrepo]
        if ghrepo != ""
            ghrepo = ghrepo.gsub("http://github.com/", "https://github.com/") # use https
            if not ghrepo.start_with?("https://github.com/")
                return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid GitHub URL - make sure it starts with https://github.com!"}
            end
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
        redirect "/?submitted=true"
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

        if request.host == "gallery.upperlinecode.com"
            redirect "/?hacky_redirect_thing=true"
        else
            redirect "/"
        end
    end

    get "/admin" do
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if not session[:is_admin]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        erb :admin, :layout => :layout, locals: {title: "Manage projects", unapproved: Project.order(created_at: :desc).where(approved: false) }
    end

    get "/approve" do
        if not params[:id]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Missing id parameter!"}
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        if not session[:is_admin]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid ID"}
        end
        p.approved = true
        p.save
        redirect "/admin"
    end


    get "/edit" do
        if not params[:id]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Missing id parameter!"}
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid ID"}
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        erb :edit, :layout => :layout, locals: {title: "Edit project", project: p}
    end

    post "/edit" do
        if not params[:id]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Missing id parameter!"}
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid ID"}
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        if params[:name] == "" or params[:authors] == "" or params[:url] == "" or params[:description] == ""
            return erb :error, :layout => :layout, locals: {title: "Error", error: "All fields except GitHub repository are required!"}
        end
        ghrepo = params[:ghrepo]
        if ghrepo != ""
            ghrepo = ghrepo.gsub("http://github.com/", "https://github.com/") # use https
            if not ghrepo.start_with?("https://github.com/")
                return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid GitHub URL - make sure it starts with https://github.com!"}
            end
        end
        p.name = params[:name]
        p.authors = params[:authors]
        p.url = params[:url]
        p.description = params[:description]
        p.github_repo = ghrepo
        p.approved = false
        p.save

        # this will delete the project's screenshot so it will be recreated later
        if File.exists?("public/screenshots/" + p.id.to_s + ".png")
            File.delete("public/screenshots/" + p.id.to_s + ".png")
        end
        redirect "/?edited=true"
    end

    get "/delete" do
        if not params[:id]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Missing id parameter!"}
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid ID"}
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        erb :delete, :layout => :layout, locals: {title: "Confirm deletion", project: p}
    end

    post "/delete" do
        if not params[:id]
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Missing id parameter!"}
        end
        if not session[:logged_in]
            redirect get_github_url(@CLIENT_ID, @CLIENT_SECRET)
        end
        p = Project.where(id: params[:id].to_i).first
        if not p
            return erb :error, :layout => :layout, locals: {title: "Error", error: "Invalid ID"}
        end
        if (p.owner and p.owner != session[:username]) and (not session[:is_admin])
            return erb :error, :layout => :layout, locals: {title: "Error", error: "You do not have access to this page. If you should, try logging out and back in again."}
        end
        Project.delete(p.id)
        redirect "/?deleted=true"
    end
end
