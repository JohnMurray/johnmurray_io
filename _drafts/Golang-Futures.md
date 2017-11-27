---
title: Bastard Go - Futures
---

Go is great. Scala is great. Scala has Futures on top of threads. Go doesn't have this
and I don't know why. 

Go has CSP and green thread things, but who wants those. Futures are the only good abstraction.
Let's make futures in Go.

{% highlight go %}
package bastard_go

type Future struct {

}
{% endhighlight %}



<!-- NOTES:

  So I found this thing called runtime.LockOSThread and runtime.UnlockOSThread which pins a goroutine to a thread and doesn't
  allow other goroutines to run on that thread. It might be fun to start the post using this mechanism and then ditch it for
  CGo and pThreads (because the whole post is ironic).

-->


 _If you made it this far and didn't realize this was sarcasm..._ ¯\\\_(ツ)_/¯
