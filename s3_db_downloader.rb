# author: Felipe JAPM | Tiago Almeida
# created_at: 29/03/2012 - 15:00

require 'yaml'
require 'digest/md5'
require 'fog'

config = YAML::load(File.open('aws_s3.yml'))

connection = Fog::Storage.new({
  :provider              => 'AWS',
  :aws_access_key_id     => config["s3"]["access_key_id"],
  :aws_secret_access_key => config["s3"]["secret_access_key"]
})

file_name = 'sql_backup.tar'
#file_date = Time.now - 15 * 24 * 60 * 60
file_path, file_etag, file_size = ''

s3_bucket = connection.directories.get('olook-sql-backups')

file_backup = s3_bucket.files.map{|file| file if file.key.match( /\/#{file_name}\Z/) }.compact.last
begin
  if file_backup
    file_path = file_backup.key
    file_etag = file_backup.about['etag'].gsub('"','')
    file_size = file_backup.about['content-length'].to_i
  end
rescue
end


puts "Found values:" if file_path || file_etag || file_size
puts file_path if file_path
puts file_etag if file_etag
puts file_size if file_size

file_path ||= file_backup.key
file_etag ||= file_backup.etag.gsub('"','')
file_size ||= file_backup.content_length.to_i

puts "Default values:"
puts file_path
puts file_etag
puts file_size

if File.exists?(file_name)
  downloaded_digest = Digest::MD5.file(file_name)
  puts "MD5: #{downloaded_digest} vs. ETAG: #{file_etag}"

  if downloaded_digest && file_etag && downloaded_digest != file_etag
    puts "------------ Removing previous generated backup ------------"
    system "rm -R sql_backup"
    system "rm #{file_name}"
  end
elsif File.exists?("sql_#{file_etag}.tar")
  # file_name = "sql_#{file_etag}.tar.bz2"
  downloaded_digest = Digest::MD5.file("sql_#{file_etag}.tar")
end

if !File.exists?(file_name) && !File.exists?("sql_#{file_etag}.tar") || downloaded_digest != file_etag
  puts "------------ Downloading last dump #{file_path} from Amazon S3. Be patient ! ------------"
  open(file_name, 'w') do |f|
    s3_bucket.files.get(file_path) do |chunk, remaining, total|
      f.write chunk
      downloaded = total - remaining
      print "\r#{"%#{total.size}d" % downloaded}/#{total} | #{"%3d" % (downloaded.to_f/total.to_f*100)}% "
    end
  end
  downloaded_digest = Digest::MD5.file(file_name)
  puts "MD5: #{downloaded_digest} vs. ETAG: #{file_etag}"
  puts ""
end

if File.exists?(file_name) && downloaded_digest == file_etag
  puts "------------ Untar the file  ------------"
  system "tar -xvf #{file_name}"
  puts "------------ Descompressing file ------------"
  system "bzip2 -d sql_backup/databases/MySQL.sql.bz2"
else
  puts "Checksum does not match. Moving on.\nUncompress for yourself and check if you can still continue"
end

puts "Ready!"

trap('INT') do
  exit
end
