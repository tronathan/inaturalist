require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservation, "creation" do
  before(:each) { setup_project_and_user }
  it "should queue a DJ job for the list" do
    stamp = Time.now
    make_project_observation(:observation => @observation, :project => @project)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
    jobs.select{|j| j.handler =~ /\:refresh_project_list\n/}.should_not be_blank
  end
  
  it "should queue a DJ job to set project user counters" do
    stamp = Time.now
    make_project_observation(:observation => @observation, :project => @project)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /\:update_observations_counter_cache/}.should_not be_blank
    jobs.select{|j| j.handler =~ /\:update_taxa_counter_cache/}.should_not be_blank
  end

  it "should destroy project invitations for its project and observation" do
    pi = ProjectInvitation.make!(:project => @project, :observation => @observation)
    make_project_observation(:observation => @observation, :project => @project)
    ProjectInvitation.find_by_id(pi.id).should be_blank
  end
end

describe ProjectObservation, "destruction" do
  before(:each) do
    setup_project_and_user
    @project_observation = make_project_observation(:observation => @observation, :project => @project)
    Delayed::Job.destroy_all
  end

  it "should queue a DJ job for the list" do
    stamp = Time.now
    @project_observation.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /\:refresh_project_list\n/}.should_not be_blank
  end
  
  it "should queue a DJ job to set project user counters" do
    stamp = Time.now
    @project_observation.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /\:update_observations_counter_cache/}.should_not be_blank
    jobs.select{|j| j.handler =~ /\:update_taxa_counter_cache/}.should_not be_blank
  end
end

describe ProjectObservation, "observed_by_project_member?" do
  
  before(:each) do 
    @project_user = ProjectUser.make!
    @project = @project_user.project
    @observation = Observation.make!(:user => @project_user.user)
    @po1 = ProjectObservation.make(:project => @project, :observation => @observation)
    @po2 = ProjectObservation.make(:observation => @observation)
  end
  
  it "should be true if observed by a member of the project" do
    @po1.should be_observed_by_project_member
  end
  
  it "should be false unless observed by a member of the project" do
    @po2.should_not be_observed_by_project_member
  end
  
end

describe ProjectObservation, "observed_in_place_bounding_box?" do
  
  it "should work" do
    setup_project_and_user
    place = Place.make!(:latitude => 0, :longitude => 0, :swlat => -1, :swlng => -1, :nelat => 1, :nelng => 1)
    @observation.update_attributes(:latitude => 0.5, :longitude => 0.5)
    project_observation = make_project_observation(:observation => @observation, :project => @project)
    project_observation.should be_observed_in_bounding_box_of(place)
  end
  
end

describe ProjectObservation, "observed_in_place" do
  it "should use private coordinates" do
    place = Place.make!(:name => "Berkeley")
    place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    # observation = Observation.make!(:latitude => 37.8732, :longitude => -122.263)
    # project_observation = make_project_observation(:observation => observation)
    
    project_observation = make_project_observation
    observation = project_observation.observation
    observation.update_attributes(:latitude => 37.8732, :longitude => -122.263)
    project_observation.reload

    project_observation.should be_observed_in_place(place)
    observation.update_attributes(:latitude => 37, :longitude => -122)
    project_observation.reload
    project_observation.should_not be_observed_in_place(place)
    observation.update_attributes(:private_latitude => 37.8732, :private_longitude => -122.263)
    observation.save
    project_observation.reload
    project_observation.should be_observed_in_place(place)
  end
end

describe ProjectObservation, "georeferenced?" do
  
  it "should work" do
    project_observation = make_project_observation
    o = project_observation.observation
    o.update_attributes(:latitude => 0.5, :longitude => 0.5)
    project_observation.reload
    project_observation.should be_georeferenced
  end
  
end

describe ProjectObservation, "identified?" do
  
  it "should work" do
    project_observation = make_project_observation
    observation = project_observation.observation
    project_observation.should_not be_identified
    observation.update_attributes(:taxon => Taxon.make!)
    project_observation.should be_identified
  end
  
end

describe ProjectObservation, "in_taxon?" do
  before(:each) do
    setup_project_and_user
  end
  
  it "should be true for observations of target taxon" do
    po = make_project_observation(:observation => @observation, :project => @project)
    po.should be_in_taxon(@observation.taxon)
  end
  
  it "should be true for observations of descendants if target taxon" do
    child = Taxon.make!(:parent => @taxon)
    o = Observation.make!(:taxon => child, :user => @project_user.user)
    po = make_project_observation(:observation => o, :project => @project)
    po.should be_in_taxon(@taxon)
  end
  
  it "should not be true for observations outside of target taxon" do
    other = Taxon.make!
    o = Observation.make!(:taxon => other, :user => @project_user.user)
    po = make_project_observation(:observation => o, :project => @project)
    po.should_not be_in_taxon(@taxon)
  end
  
  it "should be false if taxon is blank" do
    o = Observation.make!(:user => @project_user.user)
    po = make_project_observation(:observation => o, :project => @project)
    po.should_not be_in_taxon(nil)
  end
  
  # changed in https://github.com/inaturalist/inaturalist/commit/f964867b31a58edfcc9fd8b5ec32d25c1729eada
  # but might be worth re-implementing with a new rule
  # it "should be false of obs has no taxon" do
  #   po = make_project_observation
  #   po.observation.taxon.should be_blank
  #   po.should_not be_in_taxon(@taxon)
  # end
end

describe ProjectObservation, "to_csv" do
  it "should include headers for project observation fields" do
    pof = ProjectObservationField.make!
    of = pof.observation_field
    p = pof.project
    po = make_project_observation(:project => p)
    ProjectObservation.to_csv([po]).to_s.should =~ /#{of.name}/
  end

  it "should include values for project observation fields" do
    pof = ProjectObservationField.make!
    of = pof.observation_field
    p = pof.project
    po = make_project_observation(:project => p)
    ofv = ObservationFieldValue.make!(:observation => po.observation, :observation_field => of, :value => "foo")
    csv = ProjectObservation.to_csv([po])
    rows = CSV.parse(csv)
    ofv_index = rows[0].index(of.name)
    rows[1][ofv_index].should eq(ofv.value)
  end
end

def setup_project_and_user
  @project_user = ProjectUser.make!
  @project = @project_user.project
  @taxon = Taxon.make!
  @observation = Observation.make!(:user => @project_user.user, :taxon => @taxon)
end
