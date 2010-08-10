require 'rubygems'

SPEC = Gem::Specification.new do |s|
  s.name = 'has_url_id'
  s.version = '0.1'
  s.date = '2010-08-10'
  s.author = 'Claas Abert'
  s.email = 'claas@cabird.de'
  s.homepage = 'http://cabird.de'
  s.summary = 'Generates a unique URL compatible text id for ActiveRecord models.'
  s.description = 'Supports scoping'
  
  s.platform = Gem::Platform::RUBY

  s.files        = Dir['README', 'Rakefile', '{lib,rails}/*.rb']
  s.require_path = 'lib'

  s.has_rdoc = false
  s.add_dependency('activerecord')
end
