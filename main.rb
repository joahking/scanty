require 'rubygems'

# this is to load the vendored sinatra
require File.dirname(__FILE__) + '/vendor/sinatra/lib/sinatra'
require 'sinatra'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'sequel'

configure do
  def sequel_db_uri
    if Blog.db and Blog.db['adapter'] == 'mysql'
      mysql_auth =  "#{ Blog.db['username'] }:#{ Blog.db['password'] }@#{ Blog.db['host'] }/"
      "#{ Blog.db['adapter'] }://#{ mysql_auth }#{ Blog.db['database'] }"
    else
      "sqlite://blog.db"
    end
  end

  require 'ostruct'
  config = YAML.load_file File.dirname(__FILE__) + '/config/config.yml'
  Blog = OpenStruct.new( config["scanty"].
                         merge({
                                 :title => "Para.pent.es blog",
                                 :header => "la web de los amantes del vuelo libre",
                                 :url => "/news"
                               }) )
  Sequel.connect(sequel_db_uri)
end

error do
  e = request.env['sinatra.error']
  puts e.to_s
  puts e.backtrace.join("\n")
  "Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

helpers do
  def admin?
    request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
  end

  def auth
    stop [ 401, 'Not authorized' ] unless admin?
  end

  # to allow blog mounted in subdomain
  def url(url = "")
    url.gsub!(/^\//, '') # nevermind, send an initial slash
    "#{Blog.url}/#{url}"
  end

  def home
    #FIXME doesn't this looks UNDRY?
    @tags = Scanty::Post.tags
    posts = Scanty::Post.reverse_order(:created_at).limit(10)
    erb :index, :locals => { :posts => posts }
  end

  def write
    '<li><a href="posts/new">write</a></li>' if admin?
  end

  def tags
    unless @tags.nil?
      list = @tags.inject("<span>") do |html, t|
        html << "<a href='/past/tags/#{t}'>#{t}</a> "
      end
      "#{list}</span>"
    end
  end
end

layout 'layout'

### Public

# sorry about these two, have not found yet a better way

# racked.rb turns /news into ""
get "" do
  home
end

# racked.rb turns /news/ into "/"
get "/" do
  home
end

get '/past/:year/:month/:day/:slug/' do
  #FIXME doesn't this looks UNDRY? see home helper method
  @tags = Scanty::Post.tags
  post = Scanty::Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  @title = post.title
  erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
  redirect url("/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/"), 301
end

get '/past' do
  posts = Scanty::Post.reverse_order(:created_at)
  @title = "Archive"
  erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  #FIXME doesn't this looks UNDRY?
  @tags = Scanty::Post.tags
  tag = params[:tag]
  posts = Scanty::Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
  @title = "Posts tagged #{tag}"
  erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
  @posts = Scanty::Post.reverse_order(:created_at).limit(10)
  content_type 'application/atom+xml', :charset => 'utf-8'
  #FIXME this view is broken due to url nesting and post full_url method
  builder :feed
end

get '/rss' do
  redirect url("/feed"), 301
end

### Admin

get '/auth' do
  erb :auth
end

post '/auth' do
  if params[:password] == Blog.admin_password
     response.set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value)
  end
  redirect url("/")
end

get '/posts/new' do
  auth
  erb :edit, :locals => { :post => Scanty::Post.new, :url => url('/posts') }
end

post '/posts' do
  auth
  post = Scanty::Post.new({ :title => params[:title], :tags => params[:tags],
                    :body => params[:body], :created_at => Time.now,
                    :slug => Scanty::Post.make_slug(params[:title]) })

  begin
    post.save
    redirect url(post.url)
  rescue
    #FIXME are there better ways of recognizing request origin?
    redirect url("/posts/new")
  end
end

get '/past/:year/:month/:day/:slug/edit' do
  auth
  post = Scanty::Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  erb :edit, :locals => { :post => post, :url => url(post.url) }
end

post '/past/:year/:month/:day/:slug/' do
  auth
  post = Scanty::Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags]
  post.body = params[:body]
  post.save
  redirect url(post.url)
end
