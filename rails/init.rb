$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'has_scoped_slug'
ActiveRecord::Base.class_eval { include ActiveRecord::Has::ScopedSlug }
