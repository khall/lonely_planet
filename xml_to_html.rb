require 'nokogiri'
require 'byebug'

class String
  def titleize
    self.gsub(/_/, ' ').capitalize
  end

  def linkify
    # byebug
    self.gsub(%r|((http[s]://)?www\.[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-\.\/_]+)|, "<a href='http://\\1'>\\1</a>")
  end
end

def xml_to_html
  raise "Usage: ruby xml_to_html.rb <taxonomy file> <destinations file> <output directory>" unless ARGV.length == 3
  [ARGV[0], ARGV[1]].each do |file|
    raise "File doesn't exist: #{file}" unless File.exists? file
  end
  raise "Output directory doesn't exist: #{ARGV[2]}" unless File.exists? ARGV[2]

  parsed_files = parse_files(ARGV[0], ARGV[1])
  create_html_files parsed_files, ARGV[2]
end

def parse_files(taxonomy_filename, destinations_filename)
  f = File.open(taxonomy_filename)
  taxonomy_doc = Nokogiri::XML(f)
  f.close

  f = File.open(destinations_filename)
  destinations_doc = Nokogiri::XML(f)
  f.close

  [taxonomy_doc, destinations_doc]
end

def create_html_files(files, output_dir)
  template = Nokogiri::HTML(File.open("example.html"))
  files[1].xpath("//destination").each do |destination|
    @previous_section = ''
    dest_html = template

    replace_destination_name dest_html, destination
    body = dest_html.at_xpath("//div[@id='main']//div[@class='content']/div[@class='inner']")
    body.inner_html = replace_content(destination, '', 2)
    navigation = dest_html.at_xpath("//div[@id='sidebar']//div[@class='inner']")
    navigation.inner_html = replace_navigation(files[0], destination.attributes['atlas_id'].value)

    dest_html
    File.open("#{output_dir}/#{destination.attributes['atlas_id'].value}.html", 'w') {|f| f.write(dest_html) }
  end
end

def replace_destination_name(template, destination)
  dest_str = template.at_xpath("//div[@id='container']/div[@id='header']/h1")
  dest_str.content = dest_str.content.gsub(/\{DESTINATION NAME\}/, destination.attribute('title-ascii').content)
  dest_str = template.at_xpath("//div[@id='main']//li[@class='first']/a")
  dest_str.content = dest_str.content.gsub(/\{DESTINATION NAME\}/, destination.attribute('title-ascii').content)
end

def replace_content(section, content, depth)
  if section.name == '#cdata-section'
    content += "<p>#{section.content.linkify}</p>"
  elsif section.name != @previous_section && section.name != 'destination'
    @previous_section = section.name
    content += "<h#{depth}>#{section.name.titleize}</h#{depth}>"
  end

  depth += 1 if depth < 6

  # always place content in order, but put overview or introductory sections (if available) first
  if important = section.at_xpath("introductory|overview")
    section.children[0].add_previous_sibling important
  end


  section.children.each do |subsection|
    next if subsection.content == "\n"
    content = replace_content(subsection, content, depth)
  end

  content
end

def replace_navigation(taxonomy, atlas_node_id)
  nav_str = ''
  node = taxonomy.at_xpath("//node[@atlas_node_id='#{atlas_node_id}']")
  parent = node.parent.at_xpath("node_name")
  if parent
    nav_str += "<p><a href='#{node.parent.attributes['atlas_node_id']}.html'>#{parent.content}</a></p>"
  end

  nav_str += "<p>#{node.at_xpath("node_name").content}</p>"

  node.children.each do |child|
    if child.at_xpath("node_name")
      nav_str += "<p><a href='#{child.attributes['atlas_node_id']}.html'>#{child.at_xpath("node_name").content}</a></p>"
    end
  end
  nav_str
end

xml_to_html