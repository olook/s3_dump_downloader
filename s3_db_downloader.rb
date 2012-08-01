# author: Felipe JAPM
# created_at: 29/03/2012 - 15:00

require 'aws/s3'
require 'yaml'
require 'digest/md5'

config = YAML::load(File.open('aws_s3.yml'))

 AWS::S3::Base.establish_connection!(
    :access_key_id     => config["s3"]["access_key_id"],
    :secret_access_key => config["s3"]["secret_access_key"]
 )

s3_date_format = Time.now.year.to_s + "." + '%02d' % Time.now.month + "." + '%02d' % Time.now.day
pattern = /\/sql_backup\/#{s3_date_format}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\/sql_backup.tar.bz2/

file_name = 'sql_backup.tar.bz2'
file_date = Time.now - 15 * 24 * 60 * 60

s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache
s3_bucket_files.each do |file|
  begin
    if file.key =~ /\/#{file_name}\Z/
      current_date = Time.parse(file.about['last-modified'].split(',')[1].gsub('GMT',''))
      if current_date > file_date
        file_path = file.key
        file_date = current_date
        file_etag = file.about['etag'].gsub('\"','')
        file_size = file.about['content-length'].to_i
      end
    end
  rescue

  end
  # print '.'
end

puts ""
puts file_path
puts file_etag
puts file_size

file_path ||= s3_bucket_files.last.key
file_etag ||= s3_bucket_files.last.about['etag'].gsub('"','')
file_size ||= s3_bucket_files.last.about['content-length'].to_i

puts ""
puts file_path
puts file_etag
puts file_size

# s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache.inspect
# file_path = s3_bucket_files.match(pattern,s3_bucket_files.rindex("#")).to_s

if File.exists?(file_name)
  downloaded_digest = Digest::MD5.file(file_name)
  puts "MD5: #{downloaded_digest} vs. ETAG: #{file_etag}"

  if downloaded_digest && file_etag && downloaded_digest != file_etag
    puts "------------ Removing previous generated backup ------------"
    system "rm -R sql_backup"
    system "rm #{file_name}"
  end
end

if !File.exists?(file_name) || downloaded_digest != file_etag
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
  system "mysql -hlocalhost -u#{config['mysql']['user']} -p#{config['mysql']['password']} #{config['mysql']['database']} < #{Dir.getwd}/sql_backup/MySQL/olook_production.sql"
end

puts "Ready!"

trap('INT') do
  exit
end
