require 'aws/s3'
require 'yaml'

config = YAML::load(File.open('aws_s3.yml'))

 AWS::S3::Base.establish_connection!(
     :access_key_id     => config["s3"]["access_key_id"],
     :secret_access_key => config["s3"]["secret_access_key"]
  )


class Time
    def Time.yesterday
        t = Time.now
        Time.at(t.to_i-86400)
    end
end

#Definition for Abacos BKP filename
abacos_s3_date_format = Time.now.year.to_s + '%02d' % Time.now.month + '%02d' % Time.yesterday.day
abacos_pt_br_mday_map = {0 => 'domingo', 1 => 'segunda', 2 => 'terca', 3 => 'quarta', 4 => 'quinta', 5 => 'sexta', 6 => 'sabado'}
#weekday = abacos_pt_br_mday_map[Time.now.wday - 1].upcase
weekday = "QUINTA"

puts "WEEKDAY #{weekday}"

#abacos_file_path_pattern = /\/abacos_bkp\/#{abacos_s3_date_format}[0-9]*_ABACOS_#{weekday}\.BAK/
#abacos_file_name_pattern = /#{abacos_s3_date_format}[0-9]*_ABACOS_#{weekday}\.BAK/

#abacos_s3_bucket_files = AWS::S3::Bucket.find('olook_sql_backups').object_cache.inspect
bucket = AWS::S3::Bucket.find('olook_sql_backups')#.object_cache.inspect
puts " Bucket #{bucket}"
#abacos_s3_bucket_files.rindex("#")
open("kkk.BAK", 'w') do |file|
    AWS::S3::S3Object.stream("201207302330090300_ABACOS_SEGUNDA.BAK", 'olook_sql_backups') do |chunk|
       file.write chunk
    end
end

puts "Files successfully downloaded!"
