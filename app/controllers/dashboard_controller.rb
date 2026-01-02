# this controller handles the dashboard pages
# when you visit /dashboard/12345, it shows health data for zip code 12345
class DashboardController < ApplicationController
  # this action shows the home page with a form to enter zip code
  def index
    # just show the form, no data needed yet
  end

  # this action shows the dashboard for a specific zip code or coordinates
  # it fetches all the health data from the database and prepares it for display
  def show
    # check if user provided coordinates instead of zip code
    @latitude = params[:lat].to_f if params[:lat].present?
    @longitude = params[:lon].to_f if params[:lon].present?
    @zip_code = params[:zip]  # get zip code from url (e.g., /dashboard/12345)
    
    # if coordinates provided, use those; otherwise require zip code
    if @latitude.present? && @longitude.present?
      # validate coordinates are reasonable (within US bounds roughly)
      unless @latitude.between?(-90, 90) && @longitude.between?(-180, 180)
        flash[:error] = "Invalid coordinates. Latitude must be -90 to 90, Longitude must be -180 to 180."
        redirect_to root_path
        return
      end
      # try to find zip code from coordinates if available
      location = OpenAqHourlyRollup
        .where('latitude BETWEEN ? AND ?', @latitude - 0.1, @latitude + 0.1)
        .where('longitude BETWEEN ? AND ?', @longitude - 0.1, @longitude + 0.1)
        .where.not(zip_code: nil)
        .select(:zip_code)
        .first
      @zip_code = location&.zip_code
    elsif @zip_code.present?
      # make sure zip code is exactly 5 digits
      unless @zip_code =~ /^\d{5}$/
        flash[:error] = "Invalid ZIP code format. Please use 5 digits."
        redirect_to root_path  # go back to home if invalid
        return
      end
    else
      flash[:error] = "Please provide either a ZIP code or coordinates (lat/lon)."
      redirect_to root_path
      return
    end

    # set up date ranges for queries
    # users can choose how many days/weeks to show for each data source
    end_date = Date.today
    
    # get number of weeks for flu data from url parameter (default to 12 if not provided)
    weeks = params[:weeks].to_i
    weeks = 12 if weeks < 1 || weeks > 52  # validate: between 1 and 52 weeks
    @weeks = weeks  # save for display in view
    week_start_date = weeks.weeks.ago.to_date
    
    # get number of days for hospital data (default to 30 if not provided)
    hospital_days = params[:hospital_days].to_i
    hospital_days = 30 if hospital_days < 1 || hospital_days > 365  # validate: between 1 and 365 days
    @hospital_days = hospital_days  # save for display
    hospital_start_date = hospital_days.days.ago.to_date
    
    # get number of days for fda data (default to 30 if not provided)
    fda_days = params[:fda_days].to_i
    fda_days = 30 if fda_days < 1 || fda_days > 365  # validate: between 1 and 365 days
    @fda_days = fda_days  # save for display
    fda_start_date = fda_days.days.ago.to_date
    
    # get number of days for air quality data (default to 30 if not provided)
    openaq_days = params[:openaq_days].to_i
    openaq_days = 30 if openaq_days < 1 || openaq_days > 365  # validate: between 1 and 365 days
    @openaq_days = openaq_days  # save for display
    openaq_start_date = openaq_days.days.ago.to_date

    # get air quality data - use coordinates if provided, otherwise use zip code
    # we have hourly data, so we group by date and calculate daily averages
    if @latitude.present? && @longitude.present?
      # search by coordinates (within 10km radius)
      air_quality_records = OpenAqHourlyRollup
        .for_coordinates_and_date_range(@latitude, @longitude, openaq_start_date, end_date, 10)
        .select("measurement_date, AVG(pm25_value) as avg_pm25, AVG(o3_value) as avg_o3")  # calculate daily averages
        .group("measurement_date")  # group by date
        .order("measurement_date")  # sort by date
    else
      # search by zip code
      air_quality_records = OpenAqHourlyRollup
        .where(zip_code: @zip_code)  # filter by zip code
        .where('measurement_date >= ? AND measurement_date <= ?', openaq_start_date, end_date)  # filter by date range
        .select("measurement_date, AVG(pm25_value) as avg_pm25, AVG(o3_value) as avg_o3")  # calculate daily averages
        .group("measurement_date")  # group by date
        .order("measurement_date")  # sort by date
    end
    
    # convert to hash format for the chart
    @air_quality_data = {}
    air_quality_records.each do |record|
      @air_quality_data[record.measurement_date] = {
        pm25_value: record.avg_pm25,  # average pm2.5 for the day
        o3_value: record.avg_o3  # average ozone for the day
      }
    end

    # get hospital capacity data - use coordinates if provided, otherwise use zip code
    if @latitude.present? && @longitude.present?
      # search by coordinates (finds nearby zip codes and filters hospitals)
      @hospital_data = HospitalCapacityDailyRollup
        .for_coordinates_and_date_range(@latitude, @longitude, hospital_start_date, end_date, 10)
        .select(:collection_date, :total_beds, :occupied_beds, :icu_beds, :covid_patients)  # only get columns we need
        .order(:collection_date)  # sort by date
    else
      # search by zip code
      @hospital_data = HospitalCapacityDailyRollup
        .for_zip_and_date_range(@zip_code, hospital_start_date, end_date)  # helper method to filter by zip and dates
        .select(:collection_date, :total_beds, :occupied_beds, :icu_beds, :covid_patients)  # only get columns we need
        .order(:collection_date)  # sort by date
    end

    # get flu data - allow user to select region (national or state)
    # try to auto-detect state from zip code, or use selected region
    flu_region = params[:flu_region].presence || 'nat'  # default to national
    @flu_region = flu_region  # save for display
    
    # try to get state from hospital data if available
    if flu_region == 'auto' || flu_region.blank?
      hospital_state_query = if @latitude.present? && @longitude.present?
        # find state from nearby hospitals (using coordinate search)
        HospitalCapacityDailyRollup
          .for_coordinates_and_date_range(@latitude, @longitude, 30.days.ago.to_date, end_date, 10)
      else
        # find state from zip code
        HospitalCapacityDailyRollup
          .where(zip_code: @zip_code)
      end
      
      hospital_state = hospital_state_query
        .where.not(state: nil)
        .select(:state)
        .distinct
        .first
      flu_region = hospital_state&.state&.downcase || 'nat'
      @flu_region = flu_region
    end
    
    @flu_data = FluviewWeeklyRollup
      .for_date_range(week_start_date, end_date, flu_region)  # filter by selected region
      .select(:epiweek_start, :wili, :ili, :num_patients)  # only get columns we need
      .order(:epiweek_start)  # sort by week

    # get fda recall data - allow user to filter by state
    fda_state = params[:fda_state].presence  # optional state filter
    @fda_state = fda_state  # save for display
    
    fda_query = FdaEnforcementDailyRollup
      .for_date_range(fda_start_date, end_date)  # filter by date range
    
    # filter by state if selected
    if fda_state.present?
      fda_query = fda_query.where('UPPER(state) = ?', fda_state.upcase)
    end
    
    @fda_data = fda_query
      .select(:report_date, :classification, :product_description, :state)  # include state for display
      .order(:report_date)  # sort by date
      .limit(50)  # only show most recent 50 recalls
    
    # get available states for dropdowns (from data we have)
    # if no data yet, provide default options
    @available_flu_regions = FluviewWeeklyRollup
      .select(:region_code)
      .distinct
      .order(:region_code)
      .pluck(:region_code)
      .compact
    
    # if no flu regions in database yet, provide common ones
    @available_flu_regions = ['nat'] if @available_flu_regions.empty?
    
    @available_fda_states = FdaEnforcementDailyRollup
      .where.not(state: nil)
      .select(:state)
      .distinct
      .order(:state)
      .pluck(:state)
      .compact
      .sort
    
    # if no fda states yet, provide empty array (will show "All States" option)
    @available_fda_states ||= []

    # get location coordinates for the map
    # use provided coordinates, or find from air quality data
    if @latitude.present? && @longitude.present?
      # use provided coordinates
      @map_center = [@longitude, @latitude]
    else
      # find coordinates from air quality data for the zip code
      location = OpenAqHourlyRollup
        .where(zip_code: @zip_code)
        .where.not(latitude: nil, longitude: nil)  # make sure coordinates exist
        .select(:latitude, :longitude)
        .first  # just get the first one

      # set map center coordinates (longitude first, then latitude)
      @map_center = if location
        [location.longitude, location.latitude]  # use actual coordinates if found
      else
        [-98.5795, 39.8283]  # default to center of usa if no location found
      end
    end

    # get list of hospitals for map markers - use coordinates if provided, otherwise use zip code
    if @latitude.present? && @longitude.present?
      # find hospitals near coordinates
      @hospital_markers = HospitalCapacityDailyRollup
        .for_coordinates_and_date_range(@latitude, @longitude, 30.days.ago.to_date, end_date, 10)
        .where.not(state: nil)  # make sure state exists
        .select(:hospital_pk, :state, :total_beds, :zip_code)  # get hospital info
        .distinct  # remove duplicates
        .limit(10)  # only show up to 10 hospitals
    else
      # find hospitals by zip code
      @hospital_markers = HospitalCapacityDailyRollup
        .where(zip_code: @zip_code)
        .where.not(state: nil)  # make sure state exists
        .select(:hospital_pk, :state, :total_beds, :zip_code)  # get hospital info
        .distinct  # remove duplicates
        .limit(10)  # only show up to 10 hospitals
    end

  rescue => e
    Rails.logger.error "Dashboard error: #{e.message}"
    flash[:error] = "Error loading dashboard data: #{e.message}"
    redirect_to root_path
  end
end

