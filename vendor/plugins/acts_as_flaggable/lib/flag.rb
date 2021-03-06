class Flag < ActiveRecord::Base
  belongs_to :flaggable, :polymorphic => true

  has_subscribers :to => {
    :comments => {:notification => "activity", :include_owner => true},
  }
  notifies_subscribers_of :self, :notification => "activity", :include_owner => true,
    :on => :update,
    :queue_if => Proc.new {|flag|
      !flag.new_record? && flag.comment_changed?
    }
  auto_subscribes :resolver, :on => :update, :if => Proc.new {|record, resource|
    record.resolved_changed? && !record.resolver.blank? && 
      !record.resolver.subscriptions.where(:resource_type => "Flag", :resource_id => record.id).exists?
  }
  
  # NOTE: Flags belong to a user
  belongs_to :user
  belongs_to :resolver, :class_name => 'User', :foreign_key => 'resolver_id'
  has_many :comments, :as => :parent, :dependent => :destroy
  
  # A user can flag a specific flaggable with a specific flag once
  validates_presence_of :flag
  validates_uniqueness_of :user_id, :scope => [:flaggable_id, :flaggable_type, :flag], :message => "has already flagged that item."
  validates_presence_of :resolver, :if => Proc.new {|f| f.resolved? }
  validate :flaggable_type_valid
  
  def flaggable_type_valid
    if FlagsController::FLAG_MODELS.include?(flaggable_type)
      true
    else
      errors.add(:flaggable_type, "can't be flagged")
    end
  end
  
  # Helper class method to lookup all flags assigned
  # to all flaggable types for a given user.
  def self.find_flags_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end
  
  # Helper class method to look up all flags for 
  # flaggable class name and flaggable id.
  def self.find_flags_for_flaggable(flaggable_str, flaggable_id)
    find(:all,
      :conditions => ["flaggable_type = ? and flaggable_id = ?", flaggable_str, flaggable_id],
      :order => "created_at DESC"
    )
  end

  # Helper class method to look up a flaggable object
  # given the flaggable class name and id 
  def self.find_flaggable(flaggable_str, flaggable_id)
    flaggable_str.constantize.find(flaggable_id)
  end
  
  def flagged_object
    eval("#{flaggable_type}.find(#{flaggable_id})")
  end
end