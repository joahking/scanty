# RAILS_ROOT/racked.rb
require File.dirname(__FILE__) + '/config/environment'
require 'thin'

# Scanty blog
require File.dirname(__FILE__) + '/blog/main'

# Make sinatra play nice
set :app_file, File.expand_path(File.dirname(__FILE__) + '/blog/main.rb')
set :public,   File.expand_path(File.dirname(__FILE__) + '/blog/public')
set :views,    File.expand_path(File.dirname(__FILE__) + '/blog/views')
set :environment, :production
disable :run, :reload

app = Rack::Builder.new {
  use Rails::Rack::Static

  # Anything /news will go to Sinatra scanty
  map "/news" do
    run Sinatra::Application
  end

  # Rest with Rails
  map "/" do
    run ActionController::Dispatcher.new
  end
}.to_app

Rack::Handler::Thin.run app, :Port => 3000, :Host => "0.0.0.0"
