# Rakefile

require "rake"
require "faker"

namespace :ics do
  DAY_START = 8.hours.in_minutes # 8 AM in minutes
  DAY_END = 20.hours.in_minutes # 8 PM in minutes
  MAX_EVENTS_PER_DAY = 5
  DAYS_TO_GENERATE = 7

  TIMEZONE = "America/Los_Angeles"
  Time.zone = TIMEZONE

  DATE_FORMAT = "%Y%m%dT%H%M%S"
  WORKING_DAYS = [ 1, 2, 3, 4, 5 ] # Monday to Friday

  desc "Generate ICS test data with random events for the next week"
  task generate: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}.ics"
    random_ics_file_name = Rails.root.join("data", file_name)

    # Generate all events first
    events = generate_random_events(name)

    # Write events to file
    Calendar.write_ics_file(random_ics_file_name, name, events)

    puts "Generated random events for #{name} at #{file_name}"
  end

  desc "Generate ICS file with no available time slots"
  task no_availability: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}_no_availability.ics"
    ics_file_name = Rails.root.join("data", file_name)

    events = generate_no_availability_events(name)
    Calendar.write_ics_file(ics_file_name, name, events)

    puts "Generated calendar with no availability for #{name} at #{file_name}"
  end

  desc "Generate ICS file with unevenly stacked days"
  task uneven_days: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}_uneven_days.ics"
    ics_file_name = Rails.root.join("data", file_name)

    events = generate_uneven_days_events(name)
    Calendar.write_ics_file(ics_file_name, name, events)

    puts "Generated calendar with unevenly stacked days for #{name} at #{file_name}"
  end

  desc "Generate ICS file with one completely free day"
  task free_day: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}_free_day.ics"
    ics_file_name = Rails.root.join("data", file_name)

    events = generate_one_free_day_events(name)
    Calendar.write_ics_file(ics_file_name, name, events)

    puts "Generated calendar with one completely free day for #{name} at #{file_name}"
  end

  desc "Generate ICS file with overlapping meetings"
  task overlapping: :environment do
    name = Faker::Name.first_name
    file_name = "#{name.downcase}_overlapping.ics"
    ics_file_name = Rails.root.join("data", file_name)

    events = generate_overlapping_events(name)
    Calendar.write_ics_file(ics_file_name, name, events)

    puts "Generated calendar with overlapping meetings for #{name} at #{file_name}"
  end

  desc "Generate available slots for a user."
  task :generate_open, [ :name ] => :environment do |t, args|
    name = args[:name]
    file_name = "#{name.downcase}.ics"
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

  # 1. Standard random events (existing implementation)
  def generate_random_events(name)
    events = []
    base_date = Time.now.in_time_zone(TIMEZONE)

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      current_date = base_date + day_offset.days

      # Skip weekends
      next unless WORKING_DAYS.include?(current_date.wday)

      current_time = DAY_START
      num_events = rand(1..MAX_EVENTS_PER_DAY)

      num_events.times do
        duration = rand(30..120)
        gap = rand(30..90)  # Ensure larger gaps for availability
        current_time += gap

        break if current_time + duration >= DAY_END

        hour = current_time / 60
        minute = current_time % 60
        event_date = current_date.change(hour: hour, min: minute)

        events << Calendar.generate_event(
          event_date,
          event_date + duration.minutes,
          Faker::Lorem.sentence(word_count: 3)
        )

        current_time += duration
      end
    end

    events
  end

  # 2. No availability - wall-to-wall meetings
  def generate_no_availability_events(name)
    events = []
    base_date = Time.now.in_time_zone(TIMEZONE)

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      current_date = base_date + day_offset.days

      # Skip weekends
      next unless WORKING_DAYS.include?(current_date.wday)

      # Create one big meeting covering entire day
      day_start_hour = DAY_START / 60
      day_start_min = DAY_START % 60
      day_end_hour = DAY_END / 60
      day_end_min = DAY_END % 60

      event_start = current_date.change(hour: day_start_hour, min: day_start_min)
      event_end = current_date.change(hour: day_end_hour, min: day_end_min)

      events << Calendar.generate_event(
        event_start,
        event_end,
        "Full day meeting"
      )
    end

    events
  end

  # 3. Unevenly stacked days
  def generate_uneven_days_events(name)
    events = []
    base_date = Time.now.in_time_zone(TIMEZONE)

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      current_date = base_date + day_offset.days

      # Skip weekends
      next unless WORKING_DAYS.include?(current_date.wday)

      # Monday and Wednesday: Very busy (many short meetings)
      if [1, 3].include?(current_date.wday)
        current_time = DAY_START
        # Create 8-10 short meetings with small gaps
        (8..16).each do |hour|
          next if hour == 12  # Skip lunch

          event_start = current_date.change(hour: hour, min: 0)
          event_end = event_start + 45.minutes

          events << Calendar.generate_event(
            event_start,
            event_end,
            "Busy day meeting"
          )
        end
      # Tuesday and Thursday: Medium busy (a few longer meetings)
      elsif [2, 4].include?(current_date.wday)
        # Morning meeting
        events << Calendar.generate_event(
          current_date.change(hour: 9, min: 0),
          current_date.change(hour: 11, min: 0),
          "Morning planning"
        )
        
        # Afternoon meeting
        events << Calendar.generate_event(
          current_date.change(hour: 14, min: 0),
          current_date.change(hour: 16, min: 0),
          "Afternoon review"
        )
      # Friday: Light schedule
      else
        # Just one meeting
        events << Calendar.generate_event(
          current_date.change(hour: 10, min: 0),
          current_date.change(hour: 11, min: 0),
          "Friday check-in"
        )
      end
    end

    events
  end

  # 4. One free day (no events)
  def generate_one_free_day_events(name)
    events = []
    base_date = Time.now.in_time_zone(TIMEZONE)

    # Choose a specific day to keep free (e.g., next Monday)
    next_monday = base_date + (8 - base_date.wday) % 7
    free_day = next_monday.to_date

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      current_date = base_date + day_offset.days

      # Skip weekends
      next unless WORKING_DAYS.include?(current_date.wday)

      # Skip the free day
      next if current_date.to_date == free_day

      # Standard meetings for all other days
      events << Calendar.generate_event(
        current_date.change(hour: 9, min: 0),
        current_date.change(hour: 11, min: 0),
        "Morning meeting"
      )
      
      events << Calendar.generate_event(
        current_date.change(hour: 14, min: 0),
        current_date.change(hour: 16, min: 0),
        "Afternoon meeting"
      )
    end

    puts "Keeping #{free_day.strftime('%A, %B %d')} free of events"
    events
  end

  # 5. Overlapping meetings
  def generate_overlapping_events(name)
    events = []
    base_date = Time.now.in_time_zone(TIMEZONE)
    
    # Choose a specific day for overlapping meetings (e.g., next Tuesday)
    next_tuesday = base_date
    while next_tuesday.wday != 2  # Tuesday
      next_tuesday += 1.day
    end
    overlap_day = next_tuesday.to_date

    (0..DAYS_TO_GENERATE - 1).each do |day_offset|
      current_date = base_date + day_offset.days

      # Skip weekends
      next unless WORKING_DAYS.include?(current_date.wday)
      
      # Standard meeting for all days
      events << Calendar.generate_event(
        current_date.change(hour: 15, min: 0),
        current_date.change(hour: 16, min: 0),
        "Regular daily meeting"
      )
      
      # Add overlapping meetings on the designated day
      if current_date.to_date == overlap_day
        # First meeting
        events << Calendar.generate_event(
          current_date.change(hour: 10, min: 0),
          current_date.change(hour: 12, min: 0),
          "Project planning"
        )
        
        # Second overlapping meeting
        events << Calendar.generate_event(
          current_date.change(hour: 11, min: 0),
          current_date.change(hour: 13, min: 0),
          "Client call (overlapping)"
        )
        
        puts "Created overlapping meetings on #{overlap_day.strftime('%A, %B %d')}"
      end
    end

    events
  end
end
