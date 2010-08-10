$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'has_url_id'
ActiveRecord::Base.class_eval { include ActiveRecord::Has::UrlId }
