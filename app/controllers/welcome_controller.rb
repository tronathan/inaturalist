class WelcomeController < ApplicationController
  MOBILIZED = [:index]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  caches_action :index, :expires_in => 15.minutes, :if => Proc.new {|c|
    !c.send(:logged_in?) && 
    c.send(:flash).blank? && 
    c.request.format != :mobile
  }
  
  def index
    @announcement = Announcement.last(:conditions => [
     'placement = \'welcome/index\' AND ? BETWEEN "start" AND "end"', Time.now.utc])
    @observations = Observation.all( 
      :include => :photos,
      :limit => 4,
      :order => "observations.created_at DESC",
      :conditions => "latitude IS NOT NULL AND longitude IS NOT NULL AND photos.id IS NOT NULL")
    
    respond_to do |format|
      format.html
      format.mobile
    end
  end
  
  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
  end

end
