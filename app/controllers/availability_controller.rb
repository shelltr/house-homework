class AvailabilityController < ApplicationController
  before_action :set_calendar

  def index
    validate_params

    # Pass the optional parameters to the available_slots method
    events = calendar.available_slots(
      start_time: params[:start_time],
      end_time: params[:end_time],
      duration: params[:duration],
      increment: params[:increment]
    )

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

  def validate_params
    unless params[:name].present?
      flash[:error] = "Name is required"
      render :error and return
    end
    
    # Optional validation for date/time parameters
    if params[:start_time].present? && !valid_datetime?(params[:start_time])
      render json: { error: "Invalid start_time format" }, status: :bad_request and return
    end
    
    if params[:end_time].present? && !valid_datetime?(params[:end_time])
      render json: { error: "Invalid end_time format" }, status: :bad_request and return
    end
    
    if params[:duration].present? && !valid_integer?(params[:duration])
      render json: { error: "Duration must be a number" }, status: :bad_request and return
    end
    
    if params[:increment].present? && !valid_integer?(params[:increment])
      render json: { error: "Increment must be a number" }, status: :bad_request and return
    end
  end
  
  # Helper methods for validation
  def valid_datetime?(value)
    begin
      DateTime.parse(value)
      true
    rescue ArgumentError
      false
    end
  end
  
  def valid_integer?(value)
    value.to_i.to_s == value.to_s
  end
end
