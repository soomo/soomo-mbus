module Mbus

  # :markup: tomdoc
  #
  # Internal: This class is intended to subclassed by all of your
  # action-specific MessageHandler classes.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

  class BaseMessageHandler

    attr_reader :message, :options

    def initialize(opts={})
      @options = opts ||= {}
    end

    # Default implementation.  Subclasses should process the message.
    def handle(msg)
      @message = msg
      puts "#{log_prefix}.handle - message: #{message}" if verbose?
    end

    def classname
      self.class.name
    end

    def log_prefix
      "#{Mbus::Io.app_name} #{classname}"
    end

    def app
      message['app']
    end

    def source_app
      app
    end

    def object
      message['object']
    end

    def action
      message['action']
    end

    def exch
      message['exch']
    end

    def rkey
      message['rkey']
    end

    def routing_key
      rkey
    end

    def sent_at
      message['sent_at']
    end

    def data
      message['data']
    end

    def verbose?
      @options[:verbose] && @options[:verbose] == true
    end

    def silent?
      @options[:silent] && @options[:silent] == true
    end

  end

end
