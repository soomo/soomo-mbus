module Mbus

  # :markup: tomdoc
  #
  # Public: This module, Mbus::Producer, is used or mixed-in by classes
  # which need to put messages on the message bus.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

  module Producer

    def mbus_enqueue(obj, action, custom_data_obj=nil)
      begin
        app   = Mbus::Config.app_name
        entry = Mbus::Config.lookup_routing_key(obj, action)
        if entry.nil?
          key = Mbus::Config.routing_lookup_key(obj, action)
          puts "Mbus::Producer.mbus_enqueue - message not sent; undefined routing key for '#{key}'" unless Mbus::Io.silent?
          nil
        else
          exch, rkey = entry['exch'], entry['routing_key']
          data = (custom_data_obj.nil?) ? obj : custom_data_obj
          json_str = build_message(app, obj, action, exch, rkey, data)
          Mbus::Io.send_message(exch, json_str, rkey)
        end
      rescue Exception => e
        puts "Mbus::Producer.mbus_enqueue Exception on #{obj.class.name} #{action} e: #{e.inspect}\n#{e.backtrace}" unless Mbus::Io.silent?
        nil
      end
    end

    def build_message(app, obj, act, exch, rkey, data)
      msg = {}
      msg['app']     = app
      msg['object']  = obj.class.name
      msg['action']  = act
      msg['exch']    = exch
      msg['rkey']    = rkey
      msg['sent_at'] = Time.now.to_f
      msg['data']    = data
      msg.to_json
    end

  end

end
