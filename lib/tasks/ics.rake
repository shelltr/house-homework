# Rakefile

require 'rake'
require 'faker'

namespace :ics do
  desc "Generate ICS test data with random events for the next week"
  task :generate do
    random_ics_file_name = Rails.root.join("data", "user_test_data_#{rand(1000000)}.ics")
    File.open(random_ics_file_name, "w") do |file|
      file.write <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        PRODID:-//Your Organization//Your Product//EN
        X-WR-CALNAME:Test Calendar
        X-WR-TIMEZONE:UTC
      ICS

      # Generate random events for the next week
      (0..6).each do |day_offset|
        event_date = Time.now.utc + (day_offset * 24 * 60 * 60) # Next week
        uid = Faker::Internet.uuid
        dtstamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        start_time = event_date.strftime('%Y%m%dT%H%M%SZ')
        end_time = (event_date + 1 * 60 * 60).strftime('%Y%m%dT%H%M%SZ') # 1 hour duration

        file.write <<~ICS
        BEGIN:VEVENT
        UID:#{uid}
        DTSTAMP:#{dtstamp}
        DTSTART:#{start_time}
        DTEND:#{end_time}
        SUMMARY:#{Faker::Lorem.sentence(word_count: 3)}
        DESCRIPTION:#{Faker::Lorem.paragraph}
        LOCATION:#{Faker::Address.full_address}
        STATUS:CONFIRMED
        END:VEVENT
        ICS
      end

      file.write <<~ICS
        END:VCALENDAR
      ICS
    end
    puts "ICS file 'user_test_data.ics' with random events has been created."
  end
end
