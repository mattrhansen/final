# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"
require "sinatra/cookies"                                                             #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "bcrypt"                                                                      #
require "twilio-ruby"                                                                 #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

hikes_table = DB.from(:hikes)
rsvps_table = DB.from(:rsvps)
users_table = DB.from(:users)

# display the new hike form (aka "new")
get "/hikes/new" do
    view "new_hike"
end

# receive the submitted signup form (aka "create")
post "/hikes/create" do
    puts "params: #{params}"

    # if there's already a user with this email, skip!
    existing_hike = hikes_table.where(location: params["location"]).to_a[0]
    if existing_hike
        view "error"
    else
        hikes_table.insert(
            title: params["title"],
            description: params["description"],
            date: params["date"],
            location: params["location"]
        )

    account_sid = ENV["TWILIO_ACCOUNT_SID"]
    auth_token = ENV["TWILIO_AUTH_TOKEN"]
    client = Twilio::REST::Client.new(account_sid, auth_token)
    client.messages.create(
        from: "+12075013031", 
        to: "+12149950874",
        body: "A new itineray has emerged! Check it out on HikeRight!")
        view "create_hike"
    end
end

before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

# homepage and list of events (aka "index")
get "/" do
    puts "params: #{params}"

    @hikes = hikes_table.all.to_a
    pp @hikes

    view "hikes"
end

# hike details (aka "show")
get "/hikes/:id" do
    puts "params: #{params}"

    @users_table = users_table
    @hike = hikes_table.where(id: params[:id]).to_a[0]
    pp @hike

    @rsvps = rsvps_table.where(hike_id: @hike[:id]).to_a
    @going_count = rsvps_table.where(hike_id: @hike[:id], going: true).count

    view "hike"
end

# display the rsvp form (aka "new")
get "/hikes/:id/rsvps/new" do
    puts "params: #{params}"

    @hike = hikes_table.where(id: params[:id]).to_a[0]
    view "new_rsvp"
end

# receive the submitted rsvp form (aka "create")
post "/hikes/:id/rsvps/create" do
    puts "params: #{params}"

    # first find the event that rsvp'ing for
    @hike = hikes_table.where(id: params[:id]).to_a[0]
    # next we want to insert a row in the rsvps table with the rsvp form data
    rsvps_table.insert(
        hike_id: @hike[:id],
        user_id: session["user_id"],
        comments: params["comments"],
        going: params["going"]
    )

    redirect "/hikes/#{@hike[:id]}"
end

# display the rsvp form (aka "edit")
get "/rsvps/:id/edit" do
    puts "params: #{params}"

    @rsvp = rsvps_table.where(id: params["id"]).to_a[0]
    @hike = hikes_table.where(id: @rsvp[:hike_id]).to_a[0]
    view "edit_rsvp"
end

# receive the submitted rsvp form (aka "update")
post "/rsvps/:id/update" do
    puts "params: #{params}"

    # find the rsvp to update
    @rsvp = rsvps_table.where(id: params["id"]).to_a[0]
    # find the rsvp's event
    @hike = hikes_table.where(id: @rsvp[:hike_id]).to_a[0]

    if @current_user && @current_user[:id] == @rsvp[:id]
        rsvps_table.where(id: params["id"]).update(
            going: params["going"],
            comments: params["comments"]
        )

        redirect "/hikes/#{@hike[:id]}"
    else
        view "error"
    end
end

# delete the rsvp (aka "destroy")
get "/rsvps/:id/destroy" do
    puts "params: #{params}"

    rsvp = rsvps_table.where(id: params["id"]).to_a[0]
    @hike = hikes_table.where(id: rsvp[:hike_id]).to_a[0]

    rsvps_table.where(id: params["id"]).delete

    redirect "/hikes/#{@hike[:id]}"
end

# display the signup form (aka "new")
get "/users/new" do
    view "new_user"
end

# receive the submitted signup form (aka "create")
post "/users/create" do
    puts "params: #{params}"

    # if there's already a user with this email, skip!
    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/logins/new"
    end
end

# display the login form (aka "new")
get "/logins/new" do
    view "new_login"
end

# receive the submitted login form (aka "create")
post "/logins/create" do
    puts "params: #{params}"

    # step 1: user with the params["email"] ?
    @user = users_table.where(email: params["email"]).to_a[0]

    if @user
        # step 2: if @user, does the encrypted password match?
        if BCrypt::Password.new(@user[:password]) == params["password"]
            # set encrypted cookie for logged in user
            session["user_id"] = @user[:id]
            redirect "/"
        else
            view "create_login_failed"
        end
    else
        view "create_login_failed"
    end
end

# logout user
get "/logout" do
    # remove encrypted cookie for logged out user
    session["user_id"] = nil
    redirect "/logins/new"
end

