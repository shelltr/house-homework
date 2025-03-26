class Calendar
  DEFAULT_TIME_SLOT_DURATION = 30.minutes
  DEFAULT_TIME_SLOT_GAP = 15.minutes
  DEFAULT_TIMEZONE = "America/Los_Angeles"
  DEFAULT_WORKING_DAYS = [ 1, 2, 3, 4, 5 ]
  DEFAULT_START_TIME = 8.hours.in_minutes # 8 AM
  DEFAULT_END_TIME = 18.hours.in_minutes # 6 PM

  def initialize(user_name)
    @user_name = user_name
  end

  def ics_file
    @ics_file ||= Rails.root.join("data", "#{@user_name.downcase}_calendar.ics")
  end

  def events
    @events ||= Icalendar::Calendar.new(@ics_file).events
  end

  def check_availability(start_time, end_time)
    events.each do |event|
      if event.start_time <= start_time && event.end_time >= end_time
        return false
      end
    end
  end

  def get_available_slots(
    start_time = Time.now,
    end_time = Time.now + 7.days,
    duration = DEFAULT_TIME_SLOT_DURATION,
    gap = DEFAULT_TIME_SLOT_GAP
  )
    available_slots = []
    current_time = start_time

    while current_time < end_time

      # Skip if the current time is not a working day
      # or if the current time is outside of the working hours
      if !DEFAULT_WORKING_DAYS.include?(current_time.wday) ||
        current_time.min < DEFAULT_START_TIME ||
        current_time.min > DEFAULT_END_TIME
        current_time += duration
        next
      end

      if check_availability(current_time, current_time + duration)
        available_slot = {
          start_time: current_time,
          end_time: current_time + duration
        }
        available_slots << available_slot
      end
      current_time += duration
    end

    available_slots
  end

  def generate_available_slots(available_slots)
    available_slots.map do |slot|
      {
        start_time: slot[:start_time],
        end_time: slot[:end_time]
      }
    end

    # Generate new ICS file
    new_ics_file = Rails.root.join("data", "#{@user_name.downcase}_calendar_available.ics")
    File.open(new_ics_file, "w") do |file|
      file.write(available_slots.to_ics)
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
      file.write <<~ICS
        BEGIN:VEVENT
        UID:#{event[:uid]}
        DTSTAMP:#{event[:dtstamp]}
        DTSTART:#{event[:start_time]}
        DTEND:#{event[:end_time]}
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
end
