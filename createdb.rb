# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
#######################################################################################

# Database schema - this should reflect your domain model

# New domain model - adds users
DB.create_table! :hikes do
  primary_key :id
  String :title
  String :description, text: true
  String :date
  String :location
end
DB.create_table! :rsvps do
  primary_key :id
  foreign_key :hike_id
  foreign_key :user_id
  Boolean :going
  String :comments, text: true
end
DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
end

# Insert initial (seed) data
hikes_table = DB.from(:hikes)

hikes_table.insert(title: "Ruby Beach", 
                    description: "Experience the best hiking beach on the West Coast Best Coast",
                    date: "June 21",
                    location: "Ruby Beach, WA")

hikes_table.insert(title: "Mount Rainier", 
                    description: "Come see the most iconoic hike in the Pacific Northwest",
                    date: "July 4",
                    location: "Mount Rainier National Park, WA")

hikes_table.insert(title: "Enchanted Valley", 
                    description: "Explore the interior of Olympic National Park- bring your bearspray!",
                    date: "July 4",
                    location: "Olympic National Park, WA")

puts "Success!"