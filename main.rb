require 'rubygems'
require 'sinatra'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'sequel'

configure do
  Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://blog.db')

  require 'ostruct'
  config = YAML.load_file 'config/config.yml'
  Blog = OpenStruct.new( config["scanty"] )
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

  # this one will load all js for code highlighting
  def all_javascripts
    Dir.entries('public/js').inject("") do |all_js, js|
      if js =~ /\.js$/
        all_js << "<script src='/js/#{js}' type='text/javascript'></script>"
      end
      all_js
    end
  end

  def all_styles
    Dir.entries('public/css').inject("") do |all_css, css|
      if css =~ /\.css$/
        all_css << "<link href='/css/#{css}' rel='stylesheet' type='text/css' />"
      end
      all_css
    end
  end

  def write
    '<li><a href="posts/new">write</a></li>' if admin?
  end

  def friends
    Blog.friends.inject("") do |friends, f|
      friends << "<li><a href='#{f["url"]}'>#{f["text"]}</a></li>"
    end unless Blog.friends.nil?
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

get '/' do
  #FIXME doesn't this looks UNDRY?
  @tags = Post.tags
  posts = Post.reverse_order(:created_at).limit(10)
  erb :index, :locals => { :posts => posts }
end

get '/past/:year/:month/:day/:slug/' do
  #FIXME doesn't this looks UNDRY?
  @tags = Post.tags
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  @title = post.title
  erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
  redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
  posts = Post.reverse_order(:created_at)
  @title = "Archive"
  erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  #FIXME doesn't this looks UNDRY?
  @tags = Post.tags
  tag = params[:tag]
  posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
  @title = "Posts tagged #{tag}"
  erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
  @posts = Post.reverse_order(:created_at).limit(10)
  content_type 'application/atom+xml', :charset => 'utf-8'
  builder :feed
end

get '/rss' do
  redirect '/feed', 301
end

### Admin

get '/auth' do
  erb :auth
end

post '/auth' do
  set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value) if params[:password] == Blog.admin_password
  redirect '/'
end

get '/posts/new' do
  auth
  erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
  auth
  post = Post.new({ :title => params[:title], :tags => params[:tags],
                    :body => params[:body], :created_at => Time.now,
                    :slug => Post.make_slug(params[:title]) })

  begin
    post.save
    redirect(post.url)
  rescue
    #FIXME are there better ways of recognizing request origin?
    redirect 'posts/new'
  end
end

get '/past/:year/:month/:day/:slug/edit' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  erb :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
  auth
  post = Post.filter(:slug => params[:slug]).first
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags]
  post.body = params[:body]
  post.save
  redirect post.url
end

