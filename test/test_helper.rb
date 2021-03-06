require 'rubygems'
require 'active_record'
require 'mocha'
require 'test/unit'
require 'logger'
require 'searchlogic'

require File.dirname(__FILE__)+'/../lib/timeline_fu'

ActiveRecord::Base.configurations = {'sqlite3' => {:adapter => 'sqlite3', :database => ':memory:'}}
ActiveRecord::Base.establish_connection('sqlite3')

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN

ActiveRecord::Schema.define(:version => 0) do
  create_table :people do |t|
    t.string  :email,    :default => ''
    t.string  :password, :default => ''
  end

  create_table :lists do |t|
    t.integer :author_id
    t.string  :title
  end

  create_table :comments do |t|
    t.integer :list_id, :author_id
    t.string  :body
  end
  
  create_table :timeline_events do |t|
    t.string   :event_type, :subject_type,  :actor_type,  :secondary_subject_type
    t.integer               :subject_id,    :actor_id,    :secondary_subject_id
    t.timestamps
  end
end

class Person < ActiveRecord::Base
  attr_accessor :new_watcher, :fire
  
  fires :follow_created,  :on     => :update, 
                          :actor  => :new_watcher, 
                          :if     => lambda { |person| !person.new_watcher.nil? }
  fires :person_updated,  :on     => :update,
                          :if     => :fire?

  has_timeline :activity, :as => :all
  
  has_timeline :comment_activity, :as => :actor, :conditions => {:subject_type => 'Comment'}

  def fire?
    new_watcher.nil? && fire
  end
end

class List < ActiveRecord::Base
  belongs_to :author, :class_name => "Person"
  has_many :comments
  
  fires :list_created_or_updated, :actor  => :author, 
                                  :on     => [:create, :update],
                                  :subject => :self
                                   
  has_timeline :activity,  :as => [:subject, :secondary_subject],
                                  :order => 'descend_by_subject_id',
                                  :dependent => :destroy
end

class Comment < ActiveRecord::Base
  belongs_to :list
  belongs_to :author, :class_name => "Person"

  fires :comment_created, :actor   => :author,
                          :on      => :create,
                          :subject => :self,
                          :secondary_subject => :list
  fires :list_updated,    :actor   => :author,
                          :on      => :update,
                          :subject => :list,
                          :secondary_subject => :self
  fires :comment_deleted, :actor   => :author,
                          :on      => :destroy,
                          :subject => :list,
                          :secondary_subject => :self
                          
  has_timeline :activity, :as => :secondary_subject
end

TimelineEvent ||= Class.new

class Test::Unit::TestCase
  protected
    def hash_for_list(opts = {})
      {:title => 'whatever'}.merge(opts)
    end
    
    def create_list(opts = {})
      List.create!(hash_for_list(opts))
    end
    
    def hash_for_person(opts = {})
      {:email => 'james'}.merge(opts)
    end
    
    def create_person(opts = {})
      Person.create!(hash_for_person(opts))
    end
end
