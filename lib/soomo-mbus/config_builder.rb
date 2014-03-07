module Mbus

	# :markup: tomdoc
	#
	# Internal: This class is used within a rake task to create the JSON
	# value for the centralized MBUS_CONFIG value.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class ConfigBuilder

		attr_reader :options, :root, :exchanges, :queues, :business_functions
		attr_reader :consumer_processes

		def initialize(opts={})
			@root, @options = {}, opts
			@exchanges, @queues,  = [], []
			@business_functions, @consumer_processes = [], []
			root[:version]   = options[:version] ||= Time.now.to_s
			root[:exchanges] = exchanges
			root[:queues]    = queues
			root[:business_functions] = business_functions
			root[:consumer_processes] = consumer_processes
		end

		def build
			build_exchanges
			build_business_functions
			build_queues
			build_consumer_processes
			JSON.pretty_generate(root)
		end

		def build_exchanges
			defaults = {:type => 'topic', :persistent => true, :mandatory => false, :immediate => false}
			required_keys = [:name, :type, :persistent]
			specifications = [
				{:name => 'soomo'},
				{:name => 'logs', :persistent => false},
				{:name => 'test'}
			]
			specifications.each { | spec |
				obj = apply_defaults(spec, defaults)
				exchanges << obj if valid?('exchange', obj, required_keys)
			}
		end

		def build_business_functions
			defaults = {:exch => default_root_routing_key}
			required_keys = [:exch, :app, :object, :action, :routing_key]
			specifications = [
				{:app => 'scheduler', :object => 'hash', :action => 'scheduled_task'},

				{:app => 'core', :object => 'hash', :action => 'response_update'},
				{:app => 'core', :object => 'hash', :action => 'grade_update'},
				{:app => 'core', :object => 'hash', :action => 'gradebook_schema_update'},
				{:app => 'core', :object => 'fixnum', :action => 'quiz_response_update'},
				{:app => 'core', :object => 'hash', :action => 'enrollment_update'},

				{:app => 'core-consumer', :object => 'hash', :action => 'audit_document_response'},

				{:app => 'sle',  :object => 'hash', :action => 'response_update'},
				{:app => 'sle-consumer',  :object => 'hash', :action => 'response_update'},

				{:app => 'discussions',  :object => 'hash', :action => 'discussion_post_create'},
				{:app => 'discussions',  :object => 'hash', :action => 'discussion_comment_create'},

				{:app => 'ca', :object => 'hash', :action => 'rebroadcast_response_updates'},
				{:app => 'ca', :object => 'hash', :action => 'course_create'},
				{:app => 'ca', :object => 'hash', :action => 'section_create'},

				{:app => 'ca-consumer', :object => 'hash', :action => 'rebroadcast_response_updates'},
				{:app => 'ca-consumer', :object => 'hash', :action => 'audit_document_response'},

				{:app => 'auditor', :object => 'hash', :action => 'audit_document_request'},

				{:exch => 'logs', :app => 'core', :object => 'string', :action => 'log_message'},
				{:exch => 'logs', :app => 'core', :object => 'hash',   :action => 'log_message'},
				{:exch => 'logs', :app => 'sle',  :object => 'hash',   :action => 'log_message'},
				{:exch => 'logs', :app => 'cac',  :object => 'hash',   :action => 'log_message'},

				{:exch => 'test', :app => 'test', :object => 'string', :action => 'test_message'},
				{:exch => 'test', :app => 'test', :object => 'hash',   :action => 'test_message'}
			]
			specifications.each { | spec |
				obj = business_function(spec, defaults)
				business_functions << obj if valid?('business_function', obj, required_keys)
			}
		end

		def build_queues
			defaults = {:exch => default_exchange, :durable => true, :ack => true}
			required_keys = [:exch, :name, :durable, :ack, :key]
			specifications = [
				{:name => 'core-scheduled_task', :key => '#.object-hash.action-scheduled_task.#'},
				{:name => 'core-ca_course_create', :key => '#.object-hash.action-course_create.#'},
				{:name => 'core-ca_section_create', :key => '#.object-hash.action-section_create.#'},
				{:name => 'core-quiz_response_update', :key => '#.object-fixnum.action-quiz_response_update.#'},
				{:name => 'core-audit_document_requests', :key => '#.object-hash.action-audit_document_request.#'},
				{:name => 'core-rebroadcast_response_updates', :key => '#.object-hash.action-rebroadcast_response_updates.#'},

				{:name => 'ca-responses',    :key => '#.object-hash.action-response_update.#'},
				{:name => 'ca-enrollments',  :key => '#.object-hash.action-enrollment_update.#'},
				{:name => 'ca-audit_document_requests', :key => '#.object-hash.action-audit_document_request.#'},

				{:name => 'bb-responses',    :key => '#.object-hash.action-response_update.#'},
				{:name => 'bb-grades',       :key => '#.object-hash.action-grade_update.#'},
				{:name => 'bb-gradebook_schema_updates', :key => '#.object-hash.action-gradebook_schema_update.#'},

				{:name => 'sle-discussion_posts', :key => '#.object-hash.action-discussion_post_create.#'},
				{:name => 'sle-discussion_comments', :key => '#.object-hash.action-discussion_comment_create.#'},
				{:name => 'sle-enrollments', :key => '#.object-hash.action-enrollment_update.#'},
				{:name => 'sle-audit_document_requests', :key => '#.object-hash.action-audit_document_request.#'},
				{:name => 'sle-rebroadcast_response_updates', :key => '#.object-hash.action-rebroadcast_response_updates.#'},

				{:name => 'auditor-audit_document_responses', :key => '#.object-hash.action-audit_document_response.#'},

				{:exch => 'logs', :name => 'status-messages', :ack => false, :key => '#.action-log_message'},

				{:exch => 'test', :name => 'test-messages', :ack => false, :key => '#.action-test_message'}
			]
			specifications.each { | spec |
				obj = apply_defaults(spec, defaults)
				queues << obj if valid?('queue', obj, required_keys)
			}
		end

		def build_consumer_processes
			defaults = {}
			required_keys = [:name, :queues]
			specifications = [
				{:app => 'ca', :name => 'ca-consumer',
				 :queues => [
					'soomo|ca-responses',
					'soomo|ca-enrollments',
					'soomo|ca-audit_document_requests'
				]},

				{:app => 'sle', :name => 'sle-consumer',
				 :queues => [
					'soomo|sle-rebroadcast_response_updates',
					'soomo|sle-discussion_posts',
					'soomo|sle-discussion_comments',
					'soomo|sle-enrollments',
					'soomo|sle-audit_document_requests'
				]},

				{:app => 'bb-pusher', :name => 'bb-pusher-consumer',
				 :queues => [
					'soomo|bb-responses',
					'soomo|bb-grades',
					'soomo|bb-gradebook_schema_updates'
				]},

				{:app => 'core', :name => 'core-consumer',
				 :queues => [
					'logs|status-messages',
					'soomo|core-rebroadcast_response_updates',
					'soomo|core-scheduled_task',
					'soomo|core-ca_course_create',
					'soomo|core-ca_section_create',
					'soomo|core-audit_document_requests',
					'soomo|core-quiz_response_update'
				]},

				{:app => 'auditor', :name => 'auditor-consumer',
				 :queues => ['soomo|auditor-audit_document_responses']},

				{:app => 'test', :name => 'test-consumer',
				 :queues => ['test|test-messages']}
			]
			specifications.each { | spec |
				obj = apply_defaults(spec, defaults)
				consumer_processes << obj if valid?('consumer_process', obj, required_keys)
			}
		end

		def default_exchange
			@options[:default_exchange] ||= ''
		end

		def default_root_routing_key
			exch = @options[:default_exchange].to_s.strip
			(exch.size > 0) ? exch : 'root'
		end

		def boolean(value, default_value)
			return default_value if value.nil?
			return value if (value == true) || (value == false)
			value.to_s.downcase == 'true'
		end

		def apply_defaults(spec, defaults)
			defaults.keys.each { | key |
				spec[key] = defaults[key] unless spec[key]
			}
			spec
		end

		def business_function(spec, defaults)
			spec = apply_defaults(spec, defaults)
			obj, app, object, action = spec[:exch], spec[:app], spec[:object], spec[:action]
			spec[:routing_key] = "#{obj}.app-#{app}.object-#{object}.action-#{action}"
			spec
		end

		def valid?(config_type, opts={}, keys=[], verbose=true)
			result = true
			keys.each { | key |
				if opts[key].nil?
					result = false
					puts "missing key #{key} in config type #{config_type}" if verbose
				end
			}
			result
		end

	end

end
