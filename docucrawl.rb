#!/usr/bin/env ruby

require 'mechanize'
require 'logger'
require 'tempfile'
require 'filemagic'
require 'yaml'
require 'graphviz'

class Docuspider
  def initialize(
    username: ENV['DOCU_USER'],
    password: ENV['DOCU_PASS'],
    login_url:,
    handle_base_url:,
    debug: false
  )
    @mech = Mechanize.new
    @debug = debug
    if @debug
      @mech.log = Logger.new $stderr
      @mech.agent.http.debug_output = $stderr
    end

    @crawl_queue = []
    @crawled = []

    @username = username
    @password = password
    @login_url = login_url
    @handle_base_url = handle_base_url

    login
  end

  def login
    page = @mech.get(@login_url)
    form = page.form_with :name => 'Login'
    form.username = @username
    form.password = @password
    form.submit
  end

  def fetch_handle(handle)
    @mech.get("#{@handle_base_url}/#{handle}")
  end

  def queue_handle(handle)
    return if @crawl_queue.include? handle
    return if @crawled.include? handle
    @crawl_queue << handle
  end

  def crawl &block
    @crawl_queue.each do |handle|
      block.call self, handle, fetch_handle(handle)
      @crawled << handle
    end
  end
end # class Docuspider

def process_doc(spider, handle, page, graph)
  puts ">>> processing #{handle}"
  content = page.response['content-type']
  puts "\tcontent-type: #{content}"
  
  file = Tempfile.new('foo')
  file.write(page.content)
  magic = FileMagic.fm.file(file.path)

  puts "\tfilemagic: #{magic}"

  text = case content
  when %r{application/msword}, %r{application/vnd.openxmlformats-officedocument.wordprocessingml.document}
    `soffice --headless --convert-to txt:Text #{file.path} --outdir /tmp`
    text_path = "#{file.path}.txt"
    begin
      output = File.read text_path
      File.unlink text_path
    rescue
      puts "\n\n\t### this should not happen ###\n\n\n"
      return
    end
    output
  when %r{application/pdf}
    `pdf2txt #{file.path}`
  when %r{application/vnd.ms-excel}, %r{application/vnd.openxmlformats-officedocument.spreadsheetml.sheet}
    # libreoffice will fail to convert a spreadsheet directly to txt, Eg.
    # soffice --headless --convert-to txt:Text <spreadsheet>
    #
    # and when converting it to csv, it will only convert the first sheet in the workbook, Eg.
    # soffice --headless --convert-to csv <spreadsheet>
    #
    # the ruby spreedsheet gem appears to only work with Excel ~ 2003
    #
    # it's a bit rediculous but we're converting spreadsheet -> pdf -> txt
    `soffice --headless --convert-to pdf #{file.path} --outdir /tmp`
    text_path = "#{file.path}.pdf"
    output = `pdf2txt #{file.path}.pdf`
    File.unlink "#{file.path}.pdf"
    output
  else
    puts "\n\n\t### unsupported format ###\n\n\n"
    return
  end

  file.close
  file.unlink
  
  refs = []
  # intentionally skip change requests
  text.scan(/((?:LDM|LPM|LSE|Document)-\d+)/) do |md|
    refs << md[0]
  end

  # filter out self references
  refs = refs.grep(/^(?!#{handle})/)

  puts "\treferences:"
  refs.each do |ref|
    puts "\t* #{ref}"

    # create an edge between the current doc and the ref
    graph.add_edges(handle, ref)
    if @recurse
      # add the ref to the crawl queue
      spider.queue_handle ref
    end
  end
end

spider = Docuspider.new(
  login_url: 'https://docushare.lsstcorp.org/docushare/dsweb/Login',
  handle_base_url: 'https://ls.st',
  #debug: true
)

graph = GraphViz.new( :G, :type => :digraph )

docs = YAML.load_file("collection-2511.yaml")

docs.each_pair do |k,v|
  spider.queue_handle k
  graph.add_nodes(k, :label => "#{k}\n#{v}")
end

@recurse = false

spider.crawl do |spider, handle, page|
  process_doc spider, handle, page, graph
end

# generate graphviz dot file
graph.output( :dot => "collection-2511.dot" )
