class AvailabilityController < ApplicationController
  def index
    # Get list of all ics files under data/user_test_data
    ics_files = Dir.glob(Rails.root.join("data", "user_test_data", "*.ics"))

    # Pick a random ics file
    ics_file = ics_files.sample

    # Parse the ics file
    calendar = Icalendar::Calendar.new(ics_file)

    # Get all events from the calendar
    events = calendar.events

    # Return the events
    render json: events
  end

  private
end
