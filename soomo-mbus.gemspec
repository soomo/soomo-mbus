# Gemspec file for the "soomo-mbus" gem.
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'soomo-mbus/version'

Gem::Specification.new do |s|
	s.name          = "soomo-mbus"
	s.version       = Mbus::VERSION
	s.platform      = Gem::Platform::RUBY
	s.authors       = ["Chris Joakim", "David Perkowski", "Matthew Bennink"]
	s.email         = ["dadiv@soomopublishing.com"]
	s.homepage      = "http://soomopublishing.com/"
	s.summary       = %q{Soomo Publishing Enterprise Message Bus based on RabbitMQ and Redis.}
	s.description   = %q{Facilitates reliable and timely inter-application queue-based communication.}
	s.require_paths = ["lib"]
	s.required_rubygems_version = ">= 1.9.2"
	s.rubyforge_project = "soomo-mbus"

	s.add_dependency 'soomo-mbus-configuration'

	s.add_runtime_dependency 'bunny', '~> 1.4.0'
	s.add_runtime_dependency 'json'
	s.add_runtime_dependency 'redis'

	s.add_development_dependency 'rake'
	s.add_development_dependency 'rspec'
	s.add_development_dependency 'sqlite3'
	s.add_development_dependency 'simplecov'

	s.files = []
	s.files << 'Rakefile'
	s.files << 'README.md'
	s.files << 'soomo-mbus.gemspec'
	s.files << 'lib/soomo-mbus.rb'
	s.files << 'lib/soomo-mbus/base_consumer_process.rb'
	s.files << 'lib/soomo-mbus/base_message_handler.rb'
	s.files << 'lib/soomo-mbus/exchange_wrapper.rb'
	s.files << 'lib/soomo-mbus/io.rb'
	s.files << 'lib/soomo-mbus/message.rb'
	s.files << 'lib/soomo-mbus/producer.rb'
	s.files << 'lib/soomo-mbus/queue_wrapper.rb'
	s.files << 'lib/soomo-mbus/version.rb'
	s.files << 'lib/tasks/mbus.rake'

	s.test_files = Dir.glob("{spec,test}/**/*.rb")

	s.post_install_message = "soomo-mbus gem, version #{Mbus::VERSION}, has been installed"
end

