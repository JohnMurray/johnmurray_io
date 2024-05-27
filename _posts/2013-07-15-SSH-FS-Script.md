---
layout:  post
title:   "SSH FS Script"
date:    2013-07-15 12:00:00
archive: true
---

Due to my employer's server-configuration, I find myself developing
on remote machines often. However, I find it a pain to setup a dev
environment on every new machine. So, I usually just end up working
local as much as possible via SSH-FS. For anyone else that had to
do this as well, here is a handly little script that will hopefully
help you out (just a little).

{% highlight python linenos %}
#!/usr/bin/env python
from subprocess import call
import os

servers = [
  {
    'host': 'some.remote.host',          # host to connect to
    'dir' : '/usr/local/supersecret/'    # remote dir to mount
  },
  {
    'host': 'some.other.remote.host',
    'dir' : '/home/USER/'
  }
]
user = os.environ['USER']


def connect():
  """
  Connect SSH-FS's
  """
  for server in servers:
    try:
      print("connecting to %s" %(server['host']))
      print("------------------------------")
      call(["sudo", "mkdir", "-p", "/Volumes/%s" % (server['host'])])
      call(["sudo", "chown", "-R", user, "/Volumes/%s" % (server['host'])])
      status = call(["sshfs",
                     "%s:%s" % (server['host'], server['dir']),
                     "/Volumes/%s" %(server['host'])])

      if status == 0:
        print("connected")
        print("mounted locally at /Volumes/%s" % (server['host']))
        print("mounted remotely at %s" % (server['dir']))
    except:
      print "Unexpected error:", sys.exc_info()[0]
    finally:
      print("\n")


def get_sudo():
  call(["echo", "Running as root. Beware!! (mwahahahaha)"])
  call(["sudo", "echo"])


get_sudo()
connect()
{% endhighlight %}
