#!/usr/bin/env ruby
# 

# Code below, stay away...
require 'rubygems'
require 'simple-graphite'
require 'trollop'
require 'yaml'
require 'socket'
require 'erb'
require 'daemons'


class Graphite
  attr_accessor :host, :port, :time, :source

  def initialize(options = {})
    @host = options[:host]
    @port = options[:port] || 2003
    @source = options[:source] || nil
    @time = Time.now.to_i
  end

  def push_to_graphite
    raise "You need to provide both the hostname and the port" if @host.nil? || @port.nil?
    socket = TCPSocket.new(@host, @port, @source )
    yield socket
    socket.close
  end

end

class TCPSocket
  def pee( metric , value )
    self.puts "#{metric} #{value} #{Time.now.to_i}"
  end
end

def graphitemagic( graphite , command, regex , metric )

  unless regex.class == Regexp
    regex = Regexp.new regex
  end

  IO.popen( "#{command} 2>/dev/null </dev/null" , 'r' ) do |pfinfo|
    pfinfo.each do |line|
      if line =~ regex
        graphite.push_to_graphite { |gg| gg.pee( metric , $1 ) }
      end
    end
  end

end

def make_my_stats( graphiteobject , things )

  things.each do |thing|

    # Takes an object, the command, and an array of tuples (hashes) for
    # the metric/regex pairs.
    graphitemagicer( graphiteobject , thing[:cmd] , thing[:pairs] )

  end
end

# The idea here is we just run the command once, for a number of metrics.
# That way, if you sudo it, it's just one incantation. And the time won't
# be spread over multiple runs. It's just neater. Okay.
def graphitemagicer( g , cmd , metricsandregexps )

  # Little inefficient doing this each time, but it needs to be available
  # to the ERB here.
  hostname = Socket.gethostname.split( '.' ).first

  raise ArgumentError, 'metricsandregexps is not an Array' unless metricsandregexps.is_a? Array

  metricsandregexps.each do |mar|

    raise TypeError, 'metrics and regexps is not made of hashes' unless mar.is_a? Hash

    IO.popen( "#{cmd} 2>/dev/null </dev/null" , 'r' ) do |c|
      c.each do |line|

        mar.each do |metric,regex|

          unless regex.class == Regexp
            regex = Regexp.new regex
          end

          if line =~ regex
            metric = ERB.new( metric ).result(binding)
            g.push_to_graphite { |gg| gg.pee( metric , $1 ) }
            # puts "Metric of #{metric} with value of #{$1}"
          end

        end
      end
    end
  end

end


def read_config( file )

  make_me_stats_on_these = nil

  if File.exists? file and File.readable? file
    begin
      make_me_stats_on_these = YAML.load_file( file )
    rescue => e
      $stderr.puts "Unable to read #{file}, due to #{e}"
      exit 10
    end
  else
    puts "Unable to load the YAML file #{file}"
    exit 5
  end

  if make_me_stats_on_these.nil?
    puts "Empty config file."
    exit 6
  end

  make_me_stats_on_these
end

# Ever so slightly hardcoded for paths.
def daemonopts()
  {
    :ontop      => false,
    :backtrace  => false,
    :dir_mode   => :normal,
    :app_name   => 'graphiteme',
    :dir        => '/var/run/graphiteme/',
    :log_output => true,
    :log_dir    => '/var/log/graphiteme/',
  }
end

def runthewholething( configfile )

  # Read the YAML config, which contains what we're talking to, and the
  # details on the metrics to collect.
  opts = read_config( configfile )

  g = Graphite.new
  g.host = opts[:graphite]
  g.port = opts[:port]
  g.source = opts[:source]

  make_me_stats_on_these = opts[:things]

  if opts[:daemon] and not opts[:daemon].nil?

    # If we have specified a log or pid dir, use that before we fork
    doptions = daemonopts()
    doptions[:dir]     = opts[:pid_dir] if opts[:pid_dir]
    doptions[:log_dir] = opts[:log_dir] if opts[:log_dir]

    # See http://daemons.rubyforge.org/classes/Daemons.html#M000007
    # for how daemons works.
    Daemons.daemonize( doptions )

    loop do
      make_my_stats( g , make_me_stats_on_these )
      sleep opts[:daemon].to_i
    end
  else
    make_my_stats( g , make_me_stats_on_these )
  end

end


# http://stackoverflow.com/questions/2249310/if-name-main-equivalent-in-ruby
if __FILE__ == $0

  opts = Trollop::options do
    opt :config, "Config file location.", :short => 'f', :type => :string, :default => 'graphiteme.yaml'
  end
  Trollop::die :config, "must exist" unless File.exist?(opts[:config]) if opts[:config]

  runthewholething opts[:config]
end

