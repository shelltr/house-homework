# Rakefile

require "rake"
require "faker"

namespace :ics do
  desc "Generate ICS test data with random events for the next week"
  task generate: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}_calendar.ics"
    random_ics_file_name = Rails.root.join("data", file_name)

    DAY_START = 8.hours.in_minutes # 8 AM in minutes
    DAY_END = 20.hours.in_minutes # 8 PM in minutes

    TIMEZONE = "America/Los_Angeles"
    Time.zone = TIMEZONE

    DATE_FORMAT = "%Y%m%dT%H%M%S"

    WORKING_DAYS = [ 1, 2, 3, 4, 5 ] # Monday to Friday

    MAX_EVENTS_PER_DAY = 15

    DAYS_TO_GENERATE = 7

    # Generate all events first
    events = generate_events(name)

    # Write events to file
    Calendar.write_ics_file(random_ics_file_name, name, events)

    puts "Generated events for #{name} at #{file_name}"
  end
end

def generate_events(name)
  events = []

  (0..DAYS_TO_GENERATE - 1).each do |day_offset|
    base_date = Time.zone.now + (day_offset * 24 * 60 * 60)

    # Skip weekends
    next unless WORKING_DAYS.include?(base_date.wday)

    current_time = DAY_START
    num_events = rand(1..MAX_EVENTS_PER_DAY)

    num_events.times do
      duration = rand(30..120)
      gap = rand(15..120)
      current_time += gap

      break if current_time + duration >= DAY_END

      hour = current_time / 60
      minute = current_time % 60
      event_date = base_date.in_time_zone(TIMEZONE).change(hour: hour, min: minute)

      events << {
        uid: Faker::Internet.uuid,
        dtstamp: Time.zone.now.strftime(DATE_FORMAT),
        start_time: event_date.strftime(DATE_FORMAT),
        end_time: (event_date + duration * 60).strftime(DATE_FORMAT),
        summary: Faker::Lorem.sentence(word_count: 3),
        description: Faker::Lorem.paragraph,
        location: Faker::Address.full_address
      }

      current_time += duration
    end
  end

  events
end
