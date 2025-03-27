class Calendar
  DEFAULT_TIME_SLOT_DURATION_IN_MINUTES = 60
  DEFAULT_TIME_SLOT_GAP_IN_MINUTES = 15
  DEFAULT_TIMEZONE = "America/Los_Angeles"
  DEFAULT_WORKING_DAYS = [ 1, 2, 3, 4, 5 ]
  DEFAULT_START_TIME_OF_DAY_IN_MINUTES = 8 * 60 # 8 AM
  DEFAULT_END_TIME_OF_DAY_IN_MINUTES = 18 * 60 # 6 PM
  DEFAULT_ANCHOR_IN_MINUTES = 15 # No one wants a meeting at 8:07 AM, anchor to next 15 minute increment
  ICS_DATETIME_FORMAT = "%Y%m%dT%H%M%S"

  def initialize(name)
    Time.zone = DEFAULT_TIMEZONE
    @name = name
    @calendar_events = Calendar.get_calendar_events(Calendar.get_ics_file_by_name(name))
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
    start_time = Time.now.in_time_zone(DEFAULT_TIMEZONE),
    end_time = Time.now.in_time_zone(DEFAULT_TIMEZONE) + 7.days,
    duration = DEFAULT_TIME_SLOT_DURATION_IN_MINUTES,
    increment = DEFAULT_TIME_SLOT_GAP_IN_MINUTES
  )
    puts "Getting available slots for #{start_time} to #{end_time} with duration #{duration}"
    time_ranges = determine_available_time_ranges(start_time, end_time, duration, increment)
    available_slots = time_ranges.map do |time_range|
      {
        start_time: time_range.first,
        end_time: time_range.last
      }
    end

    available_slots.map do |slot|
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
    # Step 1: Set up the time boundaries
    start_time = start_time.in_time_zone(DEFAULT_TIMEZONE)
    end_time = end_time.in_time_zone(DEFAULT_TIMEZONE)
    
    # Step 2: Create an array of busy time ranges
    busy_times = @calendar_events.map do |event|
      (event[:start_time].in_time_zone(DEFAULT_TIMEZONE)..
       event[:end_time].in_time_zone(DEFAULT_TIMEZONE))
    end
    
    # Step 3: Find available slots
    available_slots = []
    
    # Process each day in the range
    (start_time.to_date..end_time.to_date).each do |date|
      # Skip non-working days
      next unless DEFAULT_WORKING_DAYS.include?(date.wday)
      
      # Set day boundaries based on working hours
      day_start = date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(
        hour: DEFAULT_START_TIME_OF_DAY_IN_MINUTES / 60,
        min: DEFAULT_START_TIME_OF_DAY_IN_MINUTES % 60
      )
      
      day_end = date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(
        hour: DEFAULT_END_TIME_OF_DAY_IN_MINUTES / 60,
        min: DEFAULT_END_TIME_OF_DAY_IN_MINUTES % 60
      )
      
      # Respect the overall search boundaries
      day_start = [day_start, start_time].max
      day_end = [day_end, end_time].min
      
      # Get busy times for this specific day
      day_busy_times = busy_times.select do |busy|
        busy.begin.to_date == date || busy.end.to_date == date
      end
      
      # Start at the first increment boundary
      current_time = day_start
      current_time = round_up_to_increment(current_time, increment)
      
      # Keep checking until we reach the end of the day
      while current_time + duration_minutes.minutes <= day_end
        slot_end = current_time + duration_minutes.minutes
        
        # Check if this slot conflicts with any busy time
        conflict = day_busy_times.any? do |busy|
          (current_time < busy.end) && (slot_end > busy.begin)
        end
        
        unless conflict
          available_slots << (current_time..slot_end)
          # Move to the next non-overlapping slot at an increment boundary
          current_time = round_up_to_increment(slot_end, increment)
        else
          # Move to the next increment boundary
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
end
