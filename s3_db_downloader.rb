# author: Felipe JAPM
# created_at: 29/03/2012 - 15:00

require 'aws/s3'
require 'yaml'

puts "------------ Removing previous generated backup ------------"
system "rm -R sql_backup"

config = YAML::load(File.open('aws_s3.yml'))

 AWS::S3::Base.establish_connection!(
    :access_key_id     => config["s3"]["access_key_id"],
    :secret_access_key => config["s3"]["secret_access_key"]
 )

s3_date_format = Time.now.year.to_s + "." + '%02d' % Time.now.month + "." + '%02d' % Time.now.day
pattern = /\/sql_backup\/#{s3_date_format}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\/sql_backup.tar.bz2/

s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache
total_file_size = s3_bucket_files.last.about['content-length'].to_i

s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache.inspect
file_path = s3_bucket_files.match(pattern,s3_bucket_files.rindex("#")).to_s

puts "------------ Downloading last dump #{file_path} from Amazon S3. Be patient ! ------------"
open('sql_backup.tar.bz2', 'w') do |file|
  AWS::S3::S3Object.stream(file_path, 'olook_sql_backups') do |chunk|
    file.write chunk
    file_size = file.size.to_i
    print "\r#{"%#{total_file_size.size}d" % file_size}/#{total_file_size} | #{"%3d" % (file_size.to_f/total_file_size.to_f*100)}% "
  end
end
puts ""

puts "------------ Descompressing file ------------"
system 'tar -xvf sql_backup.tar.bz2'

puts "------------ Restoring database #{config['mysql']['database']} ------------"
system "mysql -hlocalhost -u#{config['mysql']['user']} -p#{config['mysql']['password']} #{config['mysql']['database']} < #{Dir.getwd}/sql_backup/MySQL/olook_production.sql"

puts "Ready!"
