require 'test_helper'

class CalendarTest < ActiveSupport::TestCase
  setup do
    # Setup common test data
    @time_now = Time.parse("2025-03-27 09:00:00").in_time_zone(Calendar::DEFAULT_TIMEZONE)
    # Use Rails' built-in time helpers instead of Mocha
    travel_to @time_now
    
    # Adjust search period to be fixed for testing
    @start_time = @time_now
    @end_time = @time_now + 7.days
    
    # Default test duration
    @duration = Calendar::DEFAULT_TIME_SLOT_DURATION_IN_MINUTES
    @increment = Calendar::DEFAULT_TIME_SLOT_GAP_IN_MINUTES
  end

  teardown do
    # Reset time after each test
    travel_back
  end
  
  test "user has random events with normal availability" do
    # Skip if no physical file exists
    skip unless File.exist?(Calendar.get_ics_file_by_name("krissy"))
    
    # Setup a calendar with some random events but gaps between them
    calendar = Calendar.new("krissy")
    
    available_slots = calendar.get_available_slots(@start_time, @end_time, @duration)
    
    # Should find at least some available slots
    assert available_slots.any?, "Should find available slots with normal random events"
    
    # Verify each slot meets requirements
    available_slots.each do |slot|
      # Should be on a working day
      assert Calendar::DEFAULT_WORKING_DAYS.include?(slot[:start_time].wday), 
             "Slot should be on a working day"
      
      # Should be within working hours
      start_minutes = slot[:start_time].hour * 60 + slot[:start_time].min
      end_minutes = slot[:end_time].hour * 60 + slot[:end_time].min
      
      assert start_minutes >= Calendar::DEFAULT_START_TIME_OF_DAY_IN_MINUTES,
             "Slot should start after working hours begin"
      assert end_minutes <= Calendar::DEFAULT_END_TIME_OF_DAY_IN_MINUTES,
             "Slot should end before working hours end"
             
      # Should be correct duration
      assert_equal @duration.minutes, slot[:end_time] - slot[:start_time],
                   "Slot should be the requested duration"
                   
      # Should start at increment boundary
      assert_equal 0, slot[:start_time].min % Calendar::DEFAULT_TIME_SLOT_GAP_IN_MINUTES,
                   "Slot should start at an increment boundary"
    end
  end
  
  test "user has no availability" do
    # Create mock calendar class instead of instance method override
    mock_calendar = create_mock_calendar_class("FullCalendar")
    
    # Override busy_times in the mock class
    def mock_calendar.busy_times
      # Create busy times for each working day
      start_date = Time.now.in_time_zone(DEFAULT_TIMEZONE).to_date
      end_date = (Time.now + 7.days).in_time_zone(DEFAULT_TIMEZONE).to_date
      
      (start_date..end_date).flat_map do |date|
        next [] unless DEFAULT_WORKING_DAYS.include?(date.wday)
        
        day_start = date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(
          hour: DEFAULT_START_TIME_OF_DAY_IN_MINUTES / 60,
          min: DEFAULT_START_TIME_OF_DAY_IN_MINUTES % 60
        )
        
        day_end = date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(
          hour: DEFAULT_END_TIME_OF_DAY_IN_MINUTES / 60,
          min: DEFAULT_END_TIME_OF_DAY_IN_MINUTES % 60
        )
        
        [day_start..day_end]
      end
    end
    
    # Create instance of the mock class
    calendar = mock_calendar.new("full_calendar")
    
    available_slots = calendar.get_available_slots(@start_time, @end_time, @duration)
    
    # Should find no available slots
    assert_empty available_slots, "Should find no available slots when calendar is full"
  end
  
  test "user has unevenly stacked days" do
    # Create mock calendar class
    mock_calendar = create_mock_calendar_class("UnevenCalendar")
    
    # Override busy_times in the mock class
    def mock_calendar.busy_times
      busy_times = []
      
      # Make 2025-03-28 very busy (Friday)
      busy_day = Date.parse("2025-03-28")
      # Add several meetings with small gaps
      (8..16).each do |hour|
        next if hour == 12 # Lunch break
        
        start_time = busy_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: hour, min: 0)
        end_time = start_time + 50.minutes
        
        busy_times << (start_time..end_time)
      end
      
      # Make 2025-03-31 light (Monday)
      light_day = Date.parse("2025-03-31")
      # Just two meetings
      busy_times << (light_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 9, min: 0)..
                    light_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 10, min: 0))
      
      busy_times << (light_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 14, min: 0)..
                    light_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 15, min: 0))
      
      busy_times
    end
    
    # Create instance of the mock class
    calendar = mock_calendar.new("uneven_calendar")
    
    available_slots = calendar.get_available_slots(@start_time, @end_time, @duration)
    
    # Should find more slots on the less busy days
    busy_day = Date.parse("2025-03-28")
    light_day = Date.parse("2025-03-31")
    
    busy_day_slots = available_slots.select { |s| s[:start_time].to_date == busy_day }
    light_day_slots = available_slots.select { |s| s[:start_time].to_date == light_day }
    
    assert light_day_slots.count > busy_day_slots.count,
           "Should find more available slots on days with fewer meetings"
  end
  
  test "user has no events on one of the days" do
    # Create mock calendar class
    mock_calendar = create_mock_calendar_class("PartiallyFreeCalendar")
    
    # Override busy_times in the mock class
    def mock_calendar.busy_times
      busy_times = []
      
      # Add meetings to all days except 2025-03-31 (Monday)
      start_date = Time.now.in_time_zone(DEFAULT_TIMEZONE).to_date
      end_date = (Time.now + 7.days).in_time_zone(DEFAULT_TIMEZONE).to_date
      
      (start_date..end_date).each do |date|
        next unless DEFAULT_WORKING_DAYS.include?(date.wday)
        next if date == Date.parse("2025-03-31") # Skip this day
        
        # Add a couple meetings each day
        busy_times << (date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 9, min: 0)..
                       date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 11, min: 0))
        
        busy_times << (date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 14, min: 0)..
                       date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 16, min: 0))
      end
      
      busy_times
    end
    
    # Create instance of the mock class
    calendar = mock_calendar.new("partially_free_calendar")
    
    available_slots = calendar.get_available_slots(@start_time, @end_time, @duration)
    
    # The free day should have slots covering the entire working day
    free_day = Date.parse("2025-03-31")
    free_day_slots = available_slots.select { |s| s[:start_time].to_date == free_day }
    
    # Calculate expected number of slots in a completely free day
    work_minutes = Calendar::DEFAULT_END_TIME_OF_DAY_IN_MINUTES - 
                  Calendar::DEFAULT_START_TIME_OF_DAY_IN_MINUTES
    max_slots = work_minutes / @duration
    
    # Allow for some flexibility due to increment boundaries
    assert free_day_slots.count >= (max_slots * 0.8),
           "Free day should have close to the maximum possible slots"
  end
  
  test "user has a day where two of their existing meetings overlap" do
    # Create mock calendar class
    mock_calendar = create_mock_calendar_class("OverlappingCalendar")
    
    # Override busy_times in the mock class
    def mock_calendar.busy_times
      busy_times = []
      
      # Add normal meetings to most days
      start_date = Time.now.in_time_zone(DEFAULT_TIMEZONE).to_date
      end_date = (Time.now + 7.days).in_time_zone(DEFAULT_TIMEZONE).to_date
      
      (start_date..end_date).each do |date|
        next unless DEFAULT_WORKING_DAYS.include?(date.wday)
        
        # Add a regular meeting
        busy_times << (date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 15, min: 0)..
                       date.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 16, min: 0))
      end
      
      # Add overlapping meetings on 2025-03-28 (Friday)
      overlap_day = Date.parse("2025-03-28")
      
      busy_times << (overlap_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 10, min: 0)..
                     overlap_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 12, min: 0))
      
      busy_times << (overlap_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 11, min: 0)..
                     overlap_day.to_time.in_time_zone(DEFAULT_TIMEZONE).change(hour: 13, min: 0))
      
      busy_times
    end
    
    # Create instance of the mock class
    calendar = mock_calendar.new("overlapping_calendar")
    
    available_slots = calendar.get_available_slots(@start_time, @end_time, @duration)
    
    # Verify that the overlapping period is properly handled
    overlap_day = Date.parse("2025-03-28")
    overlap_slots = available_slots.select { |s| s[:start_time].to_date == overlap_day }
    
    # Check that no slots are within the overlapping period
    overlap_start = Time.parse("2025-03-28 10:00:00").in_time_zone(Calendar::DEFAULT_TIMEZONE)
    overlap_end = Time.parse("2025-03-28 13:00:00").in_time_zone(Calendar::DEFAULT_TIMEZONE)
    
    assert overlap_slots.none? { |slot| 
      (slot[:start_time] >= overlap_start && slot[:start_time] < overlap_end) ||
      (slot[:end_time] > overlap_start && slot[:end_time] <= overlap_end)
    }, "No slots should exist within the overlapping meeting period"
  end
  
  private
  
  # Creates a mock calendar class that inherits from Calendar
  def create_mock_calendar_class(class_name)
    # Create a subclass of Calendar
    mock_class = Class.new(Calendar) do
      # Override initialize to avoid loading events from file
      def initialize(name)
        @name = name
        # Don't call super to avoid loading from file
        Time.zone = DEFAULT_TIMEZONE
        @calendar_events = []
      end
    end
    
    # Set a name for the class for better debugging
    Object.const_set(class_name, mock_class)
    mock_class
  end
end 

  # Helper methods to build test calendars
  def build_full_calendar(name)
    # Create a stub calendar with events covering all working hours
    calendar = Calendar.new(name)
    
    # Replace the busy_times method to return wall-to-wall meetings
    calendar.define_singleton_method(:busy_times) do
      # Create busy times for each working day
      (@start_time.to_date..@end_time.to_date).flat_map do |date|
        next [] unless Calendar::DEFAULT_WORKING_DAYS.include?(date.wday)
        
        day_start = date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(
          hour: Calendar::DEFAULT_START_TIME_OF_DAY_IN_MINUTES / 60,
          min: Calendar::DEFAULT_START_TIME_OF_DAY_IN_MINUTES % 60
        )
        
        day_end = date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(
          hour: Calendar::DEFAULT_END_TIME_OF_DAY_IN_MINUTES / 60,
          min: Calendar::DEFAULT_END_TIME_OF_DAY_IN_MINUTES % 60
        )
        
        [day_start..day_end]
      end
    end
    
    calendar
  end
  
  def build_uneven_calendar(name)
    calendar = Calendar.new(name)
    
    # Replace the busy_times method to return uneven day distribution
    calendar.define_singleton_method(:busy_times) do
      busy_times = []
      
      # Make 2025-03-28 very busy (Friday)
      busy_day = Date.parse("2025-03-28")
      # Add several meetings with small gaps
      (8..16).each do |hour|
        next if hour == 12 # Lunch break
        
        start_time = busy_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: hour, min: 0)
        end_time = start_time + 50.minutes
        
        busy_times << (start_time..end_time)
      end
      
      # Make 2025-03-31 light (Monday)
      light_day = Date.parse("2025-03-31")
      # Just two meetings
      busy_times << (light_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 9, min: 0)..
                    light_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 10, min: 0))
      
      busy_times << (light_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 14, min: 0)..
                    light_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 15, min: 0))
      
      busy_times
    end
    
    calendar
  end
  
  def build_partially_free_calendar(name)
    calendar = Calendar.new(name)
    
    # Replace the busy_times method to have one completely free day
    calendar.define_singleton_method(:busy_times) do
      busy_times = []
      
      # Add meetings to all days except 2025-03-31 (Monday)
      (@start_time.to_date..@end_time.to_date).each do |date|
        next unless Calendar::DEFAULT_WORKING_DAYS.include?(date.wday)
        next if date == Date.parse("2025-03-31") # Skip this day
        
        # Add a couple meetings each day
        busy_times << (date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 9, min: 0)..
                       date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 11, min: 0))
        
        busy_times << (date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 14, min: 0)..
                       date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 16, min: 0))
      end
      
      busy_times
    end
    
    calendar
  end
  
  def build_overlapping_calendar(name)
    calendar = Calendar.new(name)
    
    # Replace the busy_times method to have overlapping meetings
    calendar.define_singleton_method(:busy_times) do
      busy_times = []
      
      # Add normal meetings to most days
      (@start_time.to_date..@end_time.to_date).each do |date|
        next unless Calendar::DEFAULT_WORKING_DAYS.include?(date.wday)
        
        # Add a regular meeting
        busy_times << (date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 15, min: 0)..
                       date.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 16, min: 0))
      end
      
      # Add overlapping meetings on 2025-03-28 (Friday)
      overlap_day = Date.parse("2025-03-28")
      
      busy_times << (overlap_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 10, min: 0)..
                     overlap_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 12, min: 0))
      
      busy_times << (overlap_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 11, min: 0)..
                     overlap_day.to_time.in_time_zone(Calendar::DEFAULT_TIMEZONE).change(hour: 13, min: 0))
      
      busy_times
    end
    
    calendar
  end
end 
