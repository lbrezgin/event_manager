require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone(phone)
  phone_num = phone.gsub(/\D/, '')
  if phone_num.length == 10
    phone_num
  elsif phone_num.length == 11 && phone_num[0] == "1"
    phone_num[1..-1]
  else
    'Unfortunately, you have entered the wrong number, so we will not be able to contact you :(('
  end
end

def time_targeting(date_time)
  date_time.group_by {|date| DateTime.strptime(date, '%m/%d/%Y %H:%M').hour }.max_by {|k,v| v.size}[0]
end

def day_targeting(date_day)
  dates = date_day.map { |date_str| DateTime.strptime(date_str, '%m/%d/%y %H:%M') }
  day_counts = dates.group_by { |date| date.strftime('%A') }.max_by { |day, dates| dates.size }[0]
end


def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event-Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

time_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone(row[:homephone])
  form_letter = erb_template.result(binding)
  time_array.push(row[:regdate])

  save_thank_you_letter(id, form_letter)
end

puts "Most popular hour for registration are: #{time_targeting(time_array)} o'clock"
puts "Most popular day for registration are: #{day_targeting(time_array)}"
