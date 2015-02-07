---
layout: post
title:  "Per-Project Console"
date:   2012-05-31 12:00:00
---

[Pry][1] is a wonderful interactive environment for Ruby. It is (more or less)
a replacement to IRB. We already know that interactive environments are highly
useful and the Rails Console is a great example of utilizing that interactive
environment effectively. 

However, if you're like me, then you don't work in Rails. The majority of my
work is in custom Ruby programs, [EM][2]-driven programs and [Sinatra][4] APIs.
You don't get anything like Rails Console for free when you're building a custom
Ruby program. So, when you start up an interactive environment, you may find
yourself starting each session like so:

{% highlight js linenos %}
require 'bundler/setup'
bundler.require(:development, :test, :console)
 
$: << File.expand_path('../src', __FILE__)
require 'app'
require 'models/user_account'
require 'models/cat'
 
# Load config and connect to DB
App.init()
 
def random_helper_method
  # ... helpful code ...
end
 
# maybe some other random junk depending 
# on what your testing at the moment
 
 
# FINALLY time to test!
{% endhighlight %}

You may keep your console running just because you don't want to have to type
all of that junk again. But eventually you will restart your computer, close
your terminal, etc. and you will loose all of the work you put into setting up
your console environment. 

My question to you (and to myself), is why go through all this trouble when
creating your own console is so easy! Just create a __console__ file in the
root of your project and insert all of that code that you would normally put
into an interactive session. You can even get fancy with a little color output
and various, generic helper methods that are useful for debugging. A console
example from one of my [current projects] looks like the following:

{% highlight ruby linenos %}
#!/usr/bin/env ruby
 
# require all the necessary files
$: << ::File.expand_path('../src', __FILE__)
require 'app'
require 'geofence'
 
# at this point bundler should be setup and the :development group
# should have been included. However, just to be sure, I'm going to
# include bundler again and require the console group.
require 'bundler/setup'
Bundler.require(:console)
 
# specify some sample fences to play with
# 
# format:
#   [
#     [:lon, :lat],
#     ...
#   ]
fence_1 = [
  [0, 0],
  [3, 0],
  [4, 2],
  [6, 3],
  [6, 6],
  [5, 7],
  [3, 5],
  [2, 4],
  [0, 1]
]
 
fence_2 = [
  [5, 5],
  [7, 5],
  [3, 2],
  [10, 2],
  [12, 7],
  [12, 10],
  [15, 10],
  [15, 15],
  [12, 15],
  [10, 18],
  [8, 15],
  [7, 15],
  [6, 13],
  [5, 10]
]
 
# patch pretty-print to use a smaller width for looking at our fences
class PP
  class << self
    alias_method :old_pp, :pp
    def pp(obj, out = $>, width = 40)
      old_pp(obj, out, width)
    end
  end
end
 
 
# include helpers to play around with Sinatra application
include Rack::Test::Methods
self.instance_eval do
  @app = App.new
  def app; @app; end
end
 
 
# add ability to reload console
def reload
  reload_msg = '# Reloading the console...'
  puts CodeRay.scan(reload_msg, :ruby).term
  Pry.save_history
  exec('./console')
end
 
g = Class.new {
  def method_missing(m, *args, &block)
    Geofence.send(m, *args, &block)
  end
}.new
 
 
# start the console! :-)
system('clear')
welcome = <<eos
# This is my interactive playground. You can call the Sinatra methods in
# the same way you would in RSpec (get, post). There are also a couple of
# test fences defined for you (fence_1, fence_2). I also monkey-patched
# 'pp' to print short arrays nicer.
#
# Everything you would want to play with (for this project) should be in here
# 
eos
puts CodeRay.scan(welcome, :ruby).term
Pry.start
{% endhighlight %}

In my console I:

- Load my project files
- Define test-data to work with
- redefine __PP.pp__ to use a shorter-width for printing out test-coordinates
- load Rack helper methods so that I can make calls to my Sinatra app from
within the console
- add the ability to reload my console
- define a helper object to call private methods on the Geofence class
- print a nice welcome message (colorized with CodeRay which is packaged with
Pry)

That's quite a bit of work if I were to do that each time I started a new
interactive Pry session. And to be honest, I just wouldn't. I would do the bare
minimum required to test something. With the console, I can have some other
niceties because I only have to write them once. So nice!

This has now become a mandatory step when _getting started_ on any new Ruby
project. I add some basics that I put into all of my console files and then
I evolve the console as the project moves forward. I can't imagine working
any other way (well... I can, I just don't prefer it).


  [1]: http://pry.github.com/
  [2]: http://rubyeventmachine.com/
  [3]: https://github.com/JohnMurray/geofence-server-example
  [4]: http://www.sinatrarb.com/
