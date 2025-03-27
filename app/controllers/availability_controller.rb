class AvailabilityController < ApplicationController
  before_action :set_calendar

  def index
    events = calendar.available_slots

    # Return the events
    render json: events
  end

  private

  def set_calendar
    if params[:name].blank?
      render json: { error: "Name is required!" }, status: :bad_request
      return
    end

    @calendar ||= Calendar.new(params[:name])
  end
end
