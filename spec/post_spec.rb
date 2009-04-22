require File.dirname(__FILE__) + '/base'

describe Scanty::Post do
  before do
    @post = Scanty::Post.new
  end

  it "has a url in simplelog format: /past/2008/10/17/my_post/" do
    @post.created_at = '2008-10-22'
    @post.slug = "my_post"
    @post.url.should == '/past/2008/10/22/my_post/'
  end

  it "has a full url including the Blog.url_base" do
    @post.created_at = '2008-10-22'
    @post.slug = "my_post"
    Blog.stub!(:url_base).and_return('http://blog.example.com/')
    @post.full_url.should == 'http://blog.example.com/past/2008/10/22/my_post/'
  end

  it "produces html from the textile body" do
    @post.body = "* Bullet"
    @post.body_html.should == "<ul>\n\t<li>Bullet</li>\n</ul>"
  end

  it "makes the tags into links to the tag search" do
    @post.tags = "one, two"
    @post.linked_tags.should ==
      "<a href='/past/tags/one'>one</a>&nbsp;<a href='/past/tags/two'>two</a>"
  end

  it "can save itself (primary key is set up)" do
    @post.title = 'hello'
    @post.body = 'world'
    @post.save
    Scanty::Post.filter(:title => 'hello').first.body.should == 'world'
  end

  it "generates a slug from the title (but saved to db on first pass so that url never changes)" do
    Scanty::Post.make_slug("RestClient 0.8").should == 'restclient_08'
    Scanty::Post.make_slug("Rushmate, rush + TextMate").should == 'rushmate_rush_textmate'
    Scanty::Post.make_slug("Object-Oriented File Manipulation").should == 'objectoriented_file_manipulation'
  end

  it 'returns sorted uniques not-nil tags list' do
    posts = [ {:body=>"code one", :tags=>nil, :title=>"no tag"},
              {:body=>"code two", :tags=>"ctag,btag", :title=>"hey there"},
              {:body=>"code three", :tags=>"web, another", :title=>"web"},
              {:body=>"code four", :tags=>"ctag,web", :title=>"repeated tags"} ]
    posts.each { |p| Scanty::Post.create p }

    Scanty::Post.tags.should == ["another", "btag", "ctag", "web"]
  end
end
