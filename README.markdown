Graphite Me!
============

# What does it do? #

It's Yet Another simple way of putting data in to graphite.

Uses YAML, of course, as the configuration file. Runs commands, parses
output, throws metrics around.

# Config #

<pre>
--- 
:graphite: 'graphite.puppetlabs.net'
:port: 2003
:daemon: 30
:things: 
- :pairs: 
  - <%= hostname %>.pf.states: !ruby/regexp / \s+ current \s entries \s+ (\d+) \s/ix
  :cmd: sudo /sbin/pfctl -s info
- :pairs: 
  - <%= hostname %>.pf.maxstates: !ruby/regexp / ^states \s+ hard \s limit \s+ (\d+) /ix
  :cmd: sudo /sbin/pfctl -s memory
</pre>

* graphite - hostname of your graphite/carbon server.
* port - which side of the boat to connect to.
* daemon - whether to daemonise and the frequency in seconds of how oft to run.
* pid_dir - where to throw pids.
* log_dir - where to throw logs.

This is where it gets... messy. 

* things - array of things to do things with.
** pairs: hash of the following...
*** arrays of a hash (I wanted a tuple) metric name (with ERB for hostname) and regexp to look for.
*** cmd: command to run, of which the output you want parsed.

"Neat" huh?

