$:.unshift File.expand_path("../lib", __FILE__)
$: << "."

require 'rubygems'
require 'bundler/gem_tasks'
require 'bunny'
require 'json'
require 'redis'
require 'rspec/core/rake_task'
require 'sqlite3'
require 'uri'
require 'soomo-mbus'

Dir[File.join(File.dirname(__FILE__),'lib/tasks/*.rake')].each { | file | load file }

RSpec::Core::RakeTask.new('spec')

task :environment do
end

