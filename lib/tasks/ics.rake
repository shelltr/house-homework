# Rakefile

require "rake"
require "faker"

namespace :ics do
  DAY_START = 8.hours.in_minutes # 8 AM in minutes
  DAY_END = 20.hours.in_minutes # 8 PM in minutes

  TIMEZONE = "America/Los_Angeles"
  Time.zone = TIMEZONE

  DATE_FORMAT = "%Y%m%dT%H%M%S"
  WORKING_DAYS = [ 1, 2, 3, 4, 5 ] # Monday to Friday

  desc "Generate ICS test data with random events for the next week"
  task generate: :environment do
    MAX_EVENTS_PER_DAY = 15
    DAYS_TO_GENERATE = 7

    name = Faker::Name.first_name
    file_name = "#{name.downcase}_calendar.ics"
    random_ics_file_name = Rails.root.join("data", file_name)

    # Generate all events first
    events = generate_events(name)
    puts events.inspect

    # Write events to file
    Calendar.write_ics_file(random_ics_file_name, name, events)

    puts "Generated events for #{name} at #{file_name}"
  end

  desc "Generate available slots for a user."
  task :generate_open, [ :name ] => :environment do |t, args|
    name = args[:name]
    file_name = "#{name.downcase}_calendar.ics"
    ics_file_path = Rails.root.join("data", file_name)
    users_calendar = Calendar.new(name)

    if !File.exist?(ics_file_path)
      puts "File #{ics_file_path} does not exist"
      exit 1
    end

    events = users_calendar.get_available_slots(Time.zone.now)
    meeting_calendar_path = Rails.root.join("data", "#{name}_available_calendar.ics")
    Calendar.write_ics_file(meeting_calendar_path, name, events)
  end

  private

  def generate_events(name)
    events = []
    base_date= Time.now.in_time_zone(TIMEZONE)

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      base_date = base_date + (day_offset * 24 * 60 * 60)

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

        events << Calendar.generate_event(
          event_date,
          event_date + duration * 60,
            Faker::Lorem.sentence(word_count: 3)
          )

          current_time += duration
        end
      end

    events
  end
end
