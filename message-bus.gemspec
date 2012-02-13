# Gemspec file for the "message-bus" gem.
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'message-bus/version'

Gem::Specification.new do |s|
  s.name          = "message-bus"
  s.version       = Mbus::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Chris Joakim", "David Perkowski", "Matthew Bennink"]
  s.email         = ["dadiv@soomopublishing.com"]
  s.homepage      = "http://soomopublishing.com/"
  s.summary       = %q{Soomo Publishing Enterprise Service Bus support based on RabbitMQ.}
  s.description   = %q{Facilitates reliable and timely inter-application communication.}
  s.require_paths = ["lib"]
  s.required_rubygems_version = ">= 1.9.2"
  # s.rubyforge_project         = "message-bus"

  s.add_runtime_dependency     'bunny', '0.7.8'

  s.files = []
  s.files << 'README.md'
  #s.files << 'Rakefile'
  s.files << 'message-bus.gemspec'
  s.files << 'lib/message-bus.rb'
  s.files << 'lib/message-bus/base_consumer_process.rb'
  s.files << 'lib/message-bus/config.rb'
  s.files << 'lib/message-bus/config_entry.rb' 
  s.files << 'lib/message-bus/io.rb'  
  s.files << 'lib/message-bus/producer.rb'
  s.files << 'lib/message-bus/sample_consumer_process.rb'
  s.files << 'lib/message-bus/version.rb' 
  
  s.test_files = Dir.glob("{spec,test}/**/*.rb")
  
  s.post_install_message = "message-bus gem, version #{Mbus::VERSION}, has been installed"
end
   