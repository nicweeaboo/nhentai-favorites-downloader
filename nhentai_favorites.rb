require 'nokogiri'
require 'rest-client'
require 'open-uri'
require 'fileutils'
require 'progress_bar'
require 'mechanize'
include ProgressBar::WithProgress

class Nhentai
  
  attr_reader :username, :password
  
  def initialize(username, password)
    @username = username.chomp
    @password = password.chomp
  end

  def run
    login
    listing
    scrapping
  end
  
  private
  
  def parsing(url)
    html = RestClient.get(url)
    Nokogiri::HTML(html)
  rescue StandardError => e
    puts "Oops..The is a problem is #{url}"
    puts "Exeception Class:#{e.class.name}"
    puts "Exception Message:#{e.message}"
  end
  
  def login
    agent = Mechanize.new
    page = agent.get 'https://nhentai.net/login/?next=%2Ffavorites%2F'
    search_form = page.form
    search_form.field_with(:name => 'username_or_email').value = @username
    search_form.field_with(:name => 'password').value = @password
    @favorites = agent.submit search_form
  end
  
  def listing
    @doujinshis_urls = Array.new
    parsed_html = Nokogiri::HTML(@favorites.body)
    doujinshis = parsed_html.xpath('/html/body/div[2]/div/div')
    doujinshis.each{|doujin| @doujinshis_urls << doujin.css('a.cover').attr('href').text}
  end
  
  def scrapping
    FileUtils.mkdir "Favorites"
    Dir.chdir("#{Dir.pwd.chomp}/Favorites") do
      @doujinshis_urls.each do |doujin|
        doujin_url = "https://nhentai.net#{doujin}"
        parsed_html = parsing(doujin_url)
        @title = info(parsed_html)
        folder = FileUtils.mkdir "#{@title}"
        puts "Downloading #{@title}"
        (1..@total).each_with_progress do |i|
          page_url = "#{doujin_url+i.to_s}"
          page_parsed = parsing(page_url)
          image = page_parsed.xpath('/html/body/div[2]/div/section[2]/a/img').attr('src').text
          Dir.chdir("#{Dir.pwd.chomp}/#{folder.join(" ")}") do
            puts "Downloading page #{i}/#{@total}"
            File.open("page#{i}", "wb") do |f|
              f.write open(image).read
            end
          end
        end
      end
    end
  end
  
  def info(doujin)
    @total = doujin.css('div#thumbnail-container>div>a>img').count
    doujin.xpath('/html/body/div[2]/div/div[2]/div/h1').text
  end
  
end

puts "/---NHENTAI FAVORITES DOWNLOADER---/"
puts "-----------------------------------------------------------------"
puts "---> Username or email: "
username = gets
puts "---> Password: "
password = gets
pevert = Nhentai.new(username, password)
pevert.run