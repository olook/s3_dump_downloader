# author: Felipe JAPM | Tiago Almeida
# created_at: 29/03/2012 - 15:00

require 'aws/s3'
require 'yaml'
require 'digest/md5'

config = YAML::load(File.open('aws_s3.yml'))

AWS::S3::Base.establish_connection!(
  :access_key_id     => config["s3"]["access_key_id"],
  :secret_access_key => config["s3"]["secret_access_key"]
)

file_name = 'sql_backup.tar'
#file_date = Time.now - 15 * 24 * 60 * 60
file_path, file_etag, file_size = ''

s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache

file_backup = s3_bucket_files.map{|file| file if file.key.match( /\/#{file_name}\Z/)}.compact.last
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

file_path ||= s3_bucket_files.last.key
file_etag ||= s3_bucket_files.last.about['etag'].gsub('"','')
file_size ||= s3_bucket_files.last.about['content-length'].to_i

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
  open(file_name, 'w') do |file|
    AWS::S3::S3Object.stream(file_path, 'olook_sql_backups') do |chunk|
      file.write chunk
      current_file_size = file.size.to_i
      print "\r#{"%#{file_size.size}d" % current_file_size}/#{file_size} | #{"%3d" % (current_file_size.to_f/file_size.to_f*100)}% "
    end
  end
  downloaded_digest = Digest::MD5.file(file_name)
  puts "MD5: #{downloaded_digest} vs. ETAG: #{file_etag}"
  puts ""
end

if File.exists?(file_name) && downloaded_digest == file_etag
  puts "------------ Descompressing file ------------"
  system "tar -xvf #{file_name}"

  puts "------------ Restoring database #{config['mysql']['database']} ------------"
  if system "mysql -hlocalhost -u#{config['mysql']['user']} -p#{config['mysql']['password']} #{config['mysql']['database']} < #{Dir.getwd}/sql_backup/MySQL/olook_production.sql"
    system "mv #{file_name} sql_#{file_etag}.tar.bz2"
  end
else
  puts "Checksum does not match. Moving on."
end

puts "Ready!"

trap('INT') do
  exit
end
