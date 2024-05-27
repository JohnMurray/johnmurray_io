---
layout: post
title:  "Twitter Future - Merging"
---

I've been doing Scala development for a while now, but I've been firmly in the land
of Lightbend (previously Typesafe) and haven't ventured out as much as I should have.
Within the past week I have been doing a lot of digging into Twitter's Scala stack when
I came across their `Future` implementation. I've long known that this has existed, but I
wasn't sure if it was still being used (it is) or what made it different. Doing a little
more digging I found a [Google Groups discussion thread][google_groups] on the topic.

There were a couple of interesting points as to what made Twitter's `Future` different than
from what is found in the standard library. One was called "merging" which can essentially
be throught of as tail recursion for `Future`s. Let's dig into this a little further.

## Future#map

If Twitter's `Future`s are mergeable, then we should be able to witness this behavior within
the `map` function of a `Future`. Let's look at the implementation.

{% highlight scala linenos %}
def map[B](f: A => B): Future[B] =
  transform {
    case Return(r) => Future { f(r) }
    case t: Throw[_] => Future.const[B](t.cast[B])
  }
{% endhighlight %}

The first thing we notice is that the entire call is wrapped in a `transform` function. That seems
important and we'll come back to that. What we're passing to the `transform` function seems to
be a partial function with the type `Try[A] => Future[B]` (that's a Twitter `Try` BTW). The function
itself seems what we would expect and isn't really anything special. The point to note is that the
function assumes that the future is completed when it is ran, which means all of the interesting
logic is in `transform`.

## Future#transform

`transform` is abstractly defined on the `Future` abstract class.

{% highlight scala linenos %}
def transform[B](f: Try[A] => Future[B]): Future[B]
{% endhighlight %}

Since this method is abstract, and since `Future` is abstract, before we dig any deeper we need
to understand the types of concrete `Future`s taht exist and their intended use.

+ `NoFuture` - A future that will never complete
+ `ConstFuture` - A future that has been completed
+ `Promise` - A completable future (writeable)

I'm not yet sure the utility in a `NoFuture`, but a `ConstFuture` is usually what you would
see when "wrapping" a value as a `Future`.

## ConstFuture#transform

Let's start by examining the `transform` function of a `ConstFuture`

{% highlight scala linenos %}
def transform[B](f: Try[A] => Future[B]): Future[B] = {
  val p = new Promise[B]
  val saved = Local.save()
  Scheduler.submit(new Runnable {
    def run() {
      val current = Local.save()
      Local.restore(saved)
      val computed = try f(result)
      catch {
        case e: NonLocalReturnControl[_] =>
          Future.exception(new FutureNonLocalReturnControl(e))
        case NonFatal(e) =>
          Future.exception(e)
        case t: Throwable =>
          Monitor.handle(t)
          throw t
      }
      finally Local.restore(current)
      p.become(computed)
    }
  })
  p
}
{% endhighlight %}

__TODO:__ explain suffs... lol

## Promise#transform

__TODO:__ explain suffs... lol




  [google_groups]: #todo (in evernote)
