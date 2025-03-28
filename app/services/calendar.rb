class Calendar
  DEFAULT_TIME_SLOT_DURATION_IN_MINUTES = 60
  DEFAULT_TIME_SLOT_GAP_IN_MINUTES = 15
  DEFAULT_TIMEZONE = "America/Los_Angeles"
  DEFAULT_WORKING_DAYS = [ 1, 2, 3, 4, 5 ]
  DEFAULT_START_TIME_OF_DAY_IN_MINUTES = 8 * 60 # 8 AM
  DEFAULT_END_TIME_OF_DAY_IN_MINUTES = 18 * 60 # 6 PM
  DEFAULT_ANCHOR_IN_MINUTES = 15 # No one wants a meeting at 8:07 AM, anchor to next 15 minute increment
  ICS_DATETIME_FORMAT = "%Y%m%dT%H%M%S"

  def initialize(agent_id, client_id = nil)
    # TODO: Currently client_id does notthing,
    # but it would be good to support client_ids as company-wide calendars
    Time.zone = DEFAULT_TIMEZONE
    @client_id = client_id
    @agent_id = agent_id

    @calendar_events = [ agent_id, client_id ].compact.map do |id|
      Calendar.get_calendar_events(Calendar.get_ics_file_by_name(id))
    end.flatten

    @busy_times = busy_times # time ranges where the user is busy
  end

  def busy_times
    sorted_events = @calendar_events.map { |event| 
      event[:start_time].in_time_zone(DEFAULT_TIMEZONE)..event[:end_time].in_time_zone(DEFAULT_TIMEZONE)  
    }.sort_by(&:first)
    merged_busy_times = []
    sorted_events.each do |busy_time|
      if merged_busy_times.any? && merged_busy_times.last.end >= busy_time.begin
        # Create a new range with the extended end time
        last_range = merged_busy_times.pop
        new_end = [last_range.end, busy_time.end].max
        merged_busy_times << (last_range.begin..new_end)
      else
        merged_busy_times << busy_time
      end
    end

    merged_busy_times
  end

  def self.get_ics_file_by_name(name)
    Rails.root.join("data", "#{name.downcase}.ics")
  end

  def available_slots(
    start_time: nil,
    end_time: nil,
    duration: nil,
    increment: nil 
  )
    # Handle yyyy-mm-dd format or use defaults
    parsed_start = parse_date_input(start_time)
    parsed_end = parse_date_input(end_time)

    # Use defaults if parsing returns nil
    start_time = parsed_start || Time.now
    end_time = parsed_end || (Time.now + 7.days)

    # Ensure we're working with times in the correct timezone
    start_time = start_time.in_time_zone(DEFAULT_TIMEZONE)
    end_time = end_time.in_time_zone(DEFAULT_TIMEZONE)

    # Log the actual date range being used
    puts "Using date range: #{start_time.to_date} (#{Date::DAYNAMES[start_time.to_date.wday]}) to #{end_time.to_date} (#{Date::DAYNAMES[end_time.to_date.wday]})"

    duration = (duration || DEFAULT_TIME_SLOT_DURATION_IN_MINUTES).to_i
    increment = (increment || DEFAULT_TIME_SLOT_GAP_IN_MINUTES).to_i

    puts "Getting available slots for #{start_time} to #{end_time} with duration #{duration}"
    time_ranges = determine_available_time_ranges(start_time, end_time, duration, increment)

    time_ranges.map do |time_range|
      {
        start_time: time_range.first,
        end_time: time_range.last,
        friendly_date: time_range.first.strftime("%A, %B %d, %Y")
      }
    end
  end

  def available_slots_to_ics(start_time: nil, end_time: nil)
    available_slots(start_time: start_time, end_time: end_time).map do |slot|
      Calendar.generate_event(
        slot[:start_time],
        slot[:end_time],
        "Available Meeting Time"
      )
    end
  end

  # Determine available slots -- they are only available
  # on the following conditions:
  # 1. It fits between two events in the user's calendar
  # 2. It is on a working day
  # 3. It is between the start and end times of the day
  def determine_available_time_ranges(start_time, end_time, duration_minutes, increment)
    # Set up time boundaries and convert to consistent timezone
    start_time = start_time.in_time_zone(DEFAULT_TIMEZONE)
    end_time = end_time.in_time_zone(DEFAULT_TIMEZONE)
    
    # Get busy time ranges
    busy_times = @calendar_events.map { |event| 
      (event[:start_time].in_time_zone(DEFAULT_TIMEZONE)..event[:end_time].in_time_zone(DEFAULT_TIMEZONE))
    }
    
    available_slots = []
    
    # Process each working day in the range
    (start_time.to_date..end_time.to_date).each do |date|
      # Skip non-working days
      next unless DEFAULT_WORKING_DAYS.include?(date.wday)
      puts "Processing working day: #{date} (#{Date::DAYNAMES[date.wday]})"

      # Create a time object at midnight of the current date in the correct timezone
      midnight = date.in_time_zone(DEFAULT_TIMEZONE).beginning_of_day

      # Set working hours relative to midnight
      day_start = midnight + DEFAULT_START_TIME_OF_DAY_IN_MINUTES.minutes
      day_end = midnight + DEFAULT_END_TIME_OF_DAY_IN_MINUTES.minutes

      # Apply overall search boundaries while preserving the correct date
      if start_time.to_date == date && start_time > day_start
        day_start = start_time
      end

      if end_time.to_date == date && end_time < day_end
        day_end = end_time
      end

      # Verify dates haven't changed
      if day_start.to_date != date || day_end.to_date != date
        next # Skip this day if dates have changed
      end

      # Get busy times for this day
      day_busy_times = busy_times.select { |busy| busy.begin.to_date <= date && busy.end.to_date >= date }

      # Find available slots
      current_time = round_up_to_increment(day_start, increment)

      while current_time + duration_minutes.minutes <= day_end
        slot_end = current_time + duration_minutes.minutes

        # Check if this slot conflicts with any busy time
        conflict = day_busy_times.any? do |busy|
          (current_time < busy.end) && (slot_end > busy.begin)
        end

        unless conflict
          available_slots << (current_time..slot_end)
          current_time = round_up_to_increment(slot_end, increment)
        else
          current_time += increment.minutes
        end
      end
    end

    available_slots
  end

  # Round up to the next increment boundary
  def round_up_to_increment(time, increment)
    minutes = time.min
    remainder = minutes % increment

    if remainder == 0
      time # Already at an increment boundary
    else
      time + (increment - remainder).minutes
    end
  end

  # Suggest slots where users have the most availability
  # in terms of raw time.
  def suggest_slots(available_slots)
    # Proceed with timezone-fixed slots
    suggested_slots_by_day = available_slots.group_by { 
      |slot| slot[:start_time].to_date 
    }

    # Sort available slots by start time within each day
    suggested_slots_by_day.each do |day, slots|
      suggested_slots_by_day[day] = slots.sort_by { |slot| slot[:start_time] }
    end

    # Sort the grouped days by the total available time for each day
    sorted_days = suggested_slots_by_day.sort_by do |day, slots|
      slots.sum { |slot| slot[:end_time] - slot[:start_time] }
    end

    # Transform into an array of hashes with formatted date keys
    sorted_days.map do |day, slots|
      {
        date: day.strftime("%Y-%m-%d"),
        day_of_week: day.strftime("%A"),
        total_available_minutes: slots.sum { |slot| (slot[:end_time] - slot[:start_time]) / 60 },
        slots: slots
      }
    end.sort_by { |day| day[:total_available_minutes] }.reverse
  end

  def find_best_available_day(available_slots)
    # Group available slots by day
    slots_by_day = available_slots.group_by { |slot| slot[:start_time].to_date }
    
    # Process each day's availability
    day_availability = {}
    
    slots_by_day.each do |date, day_slots|
      # Calculate total available minutes
      total_minutes = day_slots.sum { |slot| ((slot[:end_time] - slot[:start_time]) / 60).to_i }
      
      day_availability[date] = {
        day_name: Date::DAYNAMES[date.wday],
        total_minutes: total_minutes,
        slot_count: day_slots.size
      }
    end
    
    # Find the day with the most available slots
    best_day = day_availability.max_by do |date, data|
      # Prioritize number of slots (80%) then total available time (20%)
      (data[:slot_count] * 10 * 0.8) + (data[:total_minutes] * 0.2)
    end&.first
    
    if best_day
      data = day_availability[best_day]
      
      return {
        date: best_day,
        day_name: data[:day_name],
        slot_count: data[:slot_count],
        total_hours: (data[:total_minutes] / 60.0).round(1)
      }
    else
      return nil
    end
  end

  private

  def self.generate_event(start_time, end_time, summary)
    event = {
      uid: SecureRandom.uuid,
      start_time: start_time,
      end_time: end_time
    }

    if summary
      event[:summary] = summary
    end

    event
  end

  # Returns an array of translated calendar events
  # dtstart and dtend are in ICS format
  # and will be converted to Time objects
  def self.get_calendar_events(calendar_file_path)
    if !File.exist?(calendar_file_path)
      puts "File #{calendar_file_path} does not exist"
      exit 1
    end

    # Note: Technically this could be a collection of calendars,
    # but we have full control over the file so it will only ever
    # contain one calendar
    puts "Getting calendar events for #{calendar_file_path}"
    calendar = File.open(calendar_file_path) do |file|
      Icalendar::Calendar.parse(file).first
    end
    events = calendar.events

    events.map do |event|
      # Force timezone to be DEFAULT_TIMEZONE regardless of what's in the file
      start_time = event.dtstart.to_time.in_time_zone(DEFAULT_TIMEZONE)
      end_time = event.dtend.to_time.in_time_zone(DEFAULT_TIMEZONE)
      {
        uid: event.uid,
        start_time: start_time,
        end_time: end_time,
        status: event.status
      }
    end
  end

  def self.write_ics_file(file_path, calendar_name, events)
    File.open(file_path, "w") do |file|
      file.write <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        PRODID:-//CallyGen//CallyGen//EN
        X-WR-CALNAME:#{calendar_name}'s Calendar
        X-WR-TIMEZONE:#{DEFAULT_TIMEZONE}
      ICS

      events.each do |event|
        # Format with timezone
        file.write <<~ICS
          BEGIN:VEVENT
          UID:#{event[:uid]}
          DTSTAMP:#{event[:start_time].strftime(ICS_DATETIME_FORMAT)}Z
          DTSTART;TZID=#{DEFAULT_TIMEZONE}:#{event[:start_time].strftime(ICS_DATETIME_FORMAT)}
          DTEND;TZID=#{DEFAULT_TIMEZONE}:#{event[:end_time].strftime(ICS_DATETIME_FORMAT)}
          SUMMARY:#{event[:summary]}
          DESCRIPTION:#{event[:description]}
          LOCATION:#{event[:location]}
          STATUS:CONFIRMED
          END:VEVENT
        ICS
      end

      file.write "END:VCALENDAR\n"
    end
  end

  def parse_calendar(file_path)
    File.open(file_path) do |file|
      calendar = Icalendar::Calendar.parse(file).first
      calendar.events.map do |event|
        start_time = event.dtstart.to_time.in_time_zone(DEFAULT_TIMEZONE)
        end_time = event.dtend.to_time.in_time_zone(DEFAULT_TIMEZONE)
        {
          summary: event.summary,
          start_time: start_time,
          end_time: end_time,
          duration: (end_time - start_time) / 60, # in minutes
          location: event.location,
          description: event.description,
          status: event.status
        }
      end
    end
  end

  # Helper method to parse different date formats
  def parse_date_input(date_input)
    return nil if date_input.nil?
    
    if date_input.is_a?(String) && date_input.match?(/^\d{4}-\d{2}-\d{2}$/)
      # Parse the date and explicitly set it in the target timezone
      year, month, day = date_input.split('-').map(&:to_i)
      
      # Create the time directly in the target timezone to avoid shifts
      return Time.use_zone(DEFAULT_TIMEZONE) do
        Time.zone.local(year, month, day, 
                        DEFAULT_START_TIME_OF_DAY_IN_MINUTES / 60, 
                        DEFAULT_START_TIME_OF_DAY_IN_MINUTES % 60)
      end
    elsif date_input.is_a?(String)
      # For full datetime strings, parse with timezone awareness
      return Time.use_zone(DEFAULT_TIMEZONE) do
        Time.zone.parse(date_input)
      end
    else
      # Already a Time/DateTime object, ensure it's in the right timezone
      return date_input.in_time_zone(DEFAULT_TIMEZONE)
    end
  rescue ArgumentError => e
    # Log the error and return nil (which will use the default)
    puts "Error parsing date '#{date_input}': #{e.message}"
    return nil
  end
end
