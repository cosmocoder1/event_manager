require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_homephone(number)
  number = number.to_s.delete "-(). "
  number.length() == 10 || (number.to_s.length() == 11 && number[0] == 1) ?
  number : "invalid phone number"
end  

#format and accumulate registration hours and days
def gather_reg_time(regdate)
  modified_regdate = DateTime.strptime(regdate, "%m/%d/%y %H:%M")
  $reg_cluster["hour"].push(modified_regdate.hour)
  $reg_cluster["days"].push(modified_regdate.wday)
end  

#find two peak registration times for marketing purposes
def peak_reg_time()
  arr_hour = $reg_cluster["hour"]
  arr_hour.map { |h| [h, arr_hour.count(h)] }.sort { |a,b| b[1] <=> a[1] }[0..2].map { |val| if !$reg_cluster["peak_times"].include?(val)
    $reg_cluster["peak_times"].push(val)
  end }

  #format hour 
  def format_hour (hour)
    if hour.to_i > 12 
      hour = (hour.to_i - 12).to_s + " P.M." 
    else 
      hour = hour + " A.M."
    end  
  end  

  #peak registration days
  arr_day = $reg_cluster["days"]
  arr_day.map { |d| [d, arr_day.count(d)] }.sort { |a,b| b[1] <=> a[1] }.map { |val| if !$reg_cluster["peak_days"].include?(val)
    $reg_cluster["peak_days"].push(val)
  end }

  #format day
  def format_day (day)
    case day
    when 0
      "Sunday"
    when 1
      "Monday"
    when 2
      "Tuesday"
    when 3
      "Wednesday"
    when 4
      "Thursday"
    when 5
      "Friday"
    when 6
      "Saturday"
    else "day error"
    end
  end  
     
  #marketing message
  puts "Peak registration times are #{format_hour($reg_cluster["peak_times"][0][0])} and #{format_hour($reg_cluster["peak_times"][1][0])} on #{format_day($reg_cluster["peak_days"][0][0])}s and #{format_day($reg_cluster["peak_days"][1][0])}s"

end  

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    )
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end  
end  
  
def save_thank_you_letter(id,form_letter)

  Dir.mkdir('output') unless Dir.exists?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end  

end  

def run_prgrm

contents = CSV.open(
  '../event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

$reg_cluster = {
  "hour" => [],
  "peak_times" => [],
  "days" => [],
  "peak_days" => []
}

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter


contents.each do |row|
  
  regdate = row[:regdate]
  homephone = clean_homephone(row[:homephone])
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  
  puts row
  gather_reg_time(regdate)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

end  

  peak_reg_time()
  
end 

run_prgrm()



  
  
