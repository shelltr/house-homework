class AvailabilityController < ApplicationController
  def index
    validate_params
    set_calendar

    # Pass the optional parameters to the available_slots method
    available_slots = @calendar.available_slots(
      start_time: params[:start_time],
      end_time: params[:end_time],
      duration: params[:duration],
      increment: params[:increment]
    )

    response = {
      available_slots: available_slots
    }

    if params[:with_suggestions].to_s.downcase == "true"
      response[:suggested_slots] = @calendar.suggest_slots(available_slots)
    end

    # Return the events
    render json: response
  end

  private

  def set_calendar
    @calendar ||= Calendar.new(params[:agent_id], params[:client_id])
  end

  def validate_params
    unless params[:agent_id].present?
      render json: { error: "Agent ID is required" }, status: :bad_request and return
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
