require 'RedCloth'

class Post < Sequel::Model
  set_schema do
    primary_key :id
    text :title
    text :body
    text :slug
    text :tags
    timestamp :created_at
  end

  validates do
   presence_of :title
   presence_of :body
  end

  # this class method bypasses validations, so the condition
  def self.make_slug(title)
    title.downcase.gsub(/ /, '_').gsub(/[^a-z0-9_]/, '').squeeze('_') unless title.nil?
  end

  # returns unique non nil tags
  # example
  # [nil, nil, "tag1,tag2", "web, another", "tag1, tag2",
  #  "tag1, tag2", "tag, tagga"]
  # returns ["tag1", "tag2", "web", "another", "tag2", "tag", " tagga"]
  def self.tags
    map(:tags).compact. # nils out
      collect { |t| t.split(',') }.flatten.uniq. # unique tags in 1-dim array
      collect { |t| t.strip } # around spaces out
  end

  def linked_tags
    tags.split(',').inject([]) do |accum, tag|
      tag.strip!
      accum << "<a href='/past/tags/#{tag}'>#{tag}</a>"
    end.join('&nbsp;') unless tags.nil?
  end

  def url
    d = created_at
    "/past/#{d.year}/#{d.month}/#{d.day}/#{slug}/"
  end

  def full_url
    Blog.url_base.gsub(/\/$/, '') + url
  end

  def body_html
    to_html(body)
  end

  def summary
    summary, more = split_content(body)
    summary
  end

  def summary_html
    to_html(summary)
  end

  def more?
    summary, more = split_content(body) unless body.nil?
    more
  end

  ########
  def to_html(textile)
    RedCloth.new(textile).to_html
  end

  def split_content(string)
    parts = string.gsub(/\r/, '').split("\n\n")
    show = []
    hide = []
    parts.each do |part|
      if show.join.length < 100
        show << part
      else
        hide << part
      end
    end
    [ to_html(show.join("\n\n")), hide.size > 0 ]
  end
end

Post.create_table unless Post.table_exists?
