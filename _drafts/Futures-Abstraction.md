---
title: The Futures Abstraction
---

<!--
  Futures are really an abstraction over a threadpool + executor + scheduler. The premise
  of this article is really to explore what using the "Future pattern" looks like when we
  take a way the actual Scala Future implementation. Then by building our own example, lead
  our way back to Futures as an abstraction.

  Goal: An article that is both very informative to programmers who are not familiar with the
  Future concept as well as more seasoned developers who may not have dug into just how Futures
  work.
-->

When it comes to concurrency, there is no shortage of options. There are the classic
[processes][wiki_proc] and [threads][wiki_thrd], the older but newly-new
[actor-based concurrency][wiki_actr], [CSP style concurrency][wiki_cspc] (looking at you Go),
and the quite popular Future/Promise. Of course there are more, but one thing they all have in common
is the goal to create a "better" abstraction for concurrent computation. This is great, if we understand
what we're abstracting.

When it comes to futures I often find posts on how to get started and use them, but not many explaining
the underlying mechanics or the model we're representing. This article will walk you through futures by
implementing them from the ground up.

Before we get started, what _is_ the future abstraction? From [Wikipedia][wiki_futr] we get

> ... future, promise, delay, and deferred refer to constructs used for synchronizing program execution
> in some concurrent programming languages. They describe an object that acts as a proxy for a result that
> is initially unknown, usually because the computation of its value is yet incomplete.

Essentially a future represents the result of some computation which will _eventually_ yield a result.
Great, now that we understand what a future is, let's build our abstraction from the ground-up.

## The Tools

For this post we'll be using [Scala][scala] without any additional libraries and will only be utilizing
threads for our concurrency, since at the OS-level threads are really all we get. We'll also make use of some
data-structures for sharing values between threads. Even though I am using Scala, I will avoid any advanced
syntaxes so those unfamiliar can still (hopefully) follow along.

## Part 1 - Concurrent Computations

Before we can get into the meat of our abstraction we need to at least be able to execute some code
concurrently which we can be done simply with threads. Using a new thread for each computation looks like

{% highlight scala %}
val concurrentComputation = new Thread(new Runnable {
  def run(): Unit = {
    println("I'm running concurrently! whoop!")
  }
})

concurrentComputation.start()
{% endhighlight %}

This is fairly simple, but some things are worth pointing out. 

  * __1)__ `Unit` means that we didn't return a value. Similar to `void` in other languages
  * __2)__ The `Thread` object does not start executing the `run` function until we call `start()`

Now even though this is simple, this is a lot of code to type for each block of code we want to run
concurrently. Let's rewrite this as a function that we can pass a block of code into.

{% highlight scala linenos %}
def future(block: => Unit): Unit = {
  val concurrentComputation = new Thread(new Runnable {
    def run(): Unit = {
      block
    }
  })

  concurrentComputation.start()
}
{% endhighlight %}

And we can now call our function like so
{% highlight scala %}
future { print("I'm running concurrently! whoop!") }
{% endhighlight %}

The Scala bits that may throw you here are

  * __1)__ `block: => Unit` is a pass-by-name value that returns a `Unit` (not executed until called)
  * __2)__ `block` on line 4 evaluates the user-provided code within the `run` method which is called
           once the `Thread` is running
  * __3)__ `{ ... }` is a block of code that is passed to `future` as the first parameter to the function

Fantastic! Now we just need to somehow return a result and we're done, right? Well, not exactly. While
that would get us pretty close to the initial definition, I want to stay a little more grounded and mimic
what a future implementation would do in practice, and we're missing something from our current function.

In a real, multi-threaded application there are often multiple operations happening at once many of which
may be simultaneously using futures. However, not all futures are equally important. For example,
pushing work to a queue that came from a user is arguably more important that flushing metrics to your
metrics store. Currently we create a thread for each future, and it is up to the threads to fight it out
with the JVM/OS scheduler for resources. A better solution would make use of of thread pools.

Thread pools are small groups of threads that work is executed on. If there is more work than threads in the
pool, then they are queued up and executed once a thread from the pool is available. We can control priority within
our application by creating larger pools for more important / time-sensitive work and smaller pools for less
important / less critical work.

Let's rewrite our `future` function to work with a Java thread pool

{% highlight scala linenos %}
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

def future(tp: ThreadPoolExecutor)(block: => Unit): Unit = {
  if (tp.isShutdown || tp.isTerminating || tp.isTerminated) {
    throw new RuntimeException(
      "Cannot execute on threadpool that is not active/running.")
  }
  tp.execute(new Runnable {
    def run(): Unit = {
      block
    }
  })
}

val tp = new ThreadPoolExecutor(4, 4, 0L,
                                TimeUnit.MILLISECONDS,
                                new LinkedBlockingQueue[Runnable])
future(tp) { print("I'm running concurrently! whoop!") }
{% endhighlight %}

We now have a `future` function that works with thread pools! To explain some things

  * __1)__ `future` has multiple parameter lists `(...)`. This allows us to continue to use the block-syntax
           for user-provided code `{ ... }`.
  * __2)__ `future` now throws a `RuntimeException` if it is given a `ThreadPoolExecutor` that is not usable
  * __3)__ `tp.execute(...)` adds work to the thread pool's queue and runs it asynchronously
  * __4)__ `tp` on line 17 is a thread pool with exactly 4 threads which uses a `LinkedBlockingQueue` as the
           backing queue when there is more work than available threads.

## Part 2 - Returning the Result

We're quickly working our way towards a future implementation, but one important thing is missing. We don't
currently have a way to return a value back to the caller. According to our definition at the beginning, we
need to use some sort of "proxy" object that will eventually contain the value. Let's define what this proxy
object could look like.

{% highlight scala linenos %}
class Future[T] {
  private var result: Option[T] = None

  // writer functions
  def write(value: T): Unit = {
    this.result = Some(value)
  }

  // read functions
  def isReady: Boolean = result.isDefined
  def get: T = {
    if (! isReady) {
      throw new RuntimeException(
        "Future is not ready yet, no value to get")
    }
    return result.get
  }
}
{% endhighlight %}

Some quick notes

* __1)__ `[T]` is a generic type of `T` to be determined by the user
* __2)__ `Option` is a type that is either present (`Some`) or absent (`None`)
* __3)__ If the future is not completed, we throw an exception on access

Now that we have our "proxy" object, we can update our `future` function to return a value using our new
`Future[T]` class.

{% highlight scala linenos %}
def future[T](tp: ThreadPoolExecutor)(block: => T): Future[T] = {
  val fut = new Future[T]
  
  if (tp.isShutdown || tp.isTerminating || tp.isTerminated) {
    throw new RuntimeException(
      "Cannot execute on threadpool that is not active/running.")
  }
  tp.execute(new Runnable {
    def run(): Unit = {
      fut.write(block)
    }
  })

  return fut
}
{% endhighlight %}

Some quick notes

  * __1)__ The `block` is now a block of code that evaluates to a type `T`
  * __2)__ `future` now has type-parameter of `T` and a return type of `Future[T]`
  * __3)__ The value of the `Future[T]` is written inside the `run` function

With this newly updated function, we can still call it the same way. The exception is that it now means
something if we capture the result.

{% highlight scala %}
val f: Future[String] = future(tp) { "I'm running concurrently! whoop!" }
{% endhighlight %}

Awesome! We have our proxy object. But the next question becomes, "how do I use it?" So if we wanted to wait
on the call we made above for `f`, we might do something like the following

{% highlight scala %}
val MaxWait = 1000
var i = 0

while (!f.isReady && i < MaxWait) {
  Thread.sleep(5)
  i += 5
}

println(f.get)
{% endhighlight %}

This code is far from ideal, but it works for what we want to do. Later on in this article we'll get to
more advanced (and more idiomatic) techniques for working with future values.

However even though this works, there are two issues with this setup. The first is that anyone can write a
value into the future. Ideally this should be hidden as part of the async processing and separated from
the `Future` object. For example, this code should not be valid

{% highlight scala %}
val f: Future[Int] = future(tp) {
  Thread.sleep(1000)  // sleep future for 1s
  5
}
f.write(6)
println(f.get())  // prints 6
{% endhighlight %}

The second issue is that the value is not immutable. Once it is written, it should not be possible to change
the value. As in our example above, once the future stops sleeping, the value would change to `5`. A future
should be the result of a single computation, and that value should never change.

First let's address the issue that anyone can write into our `Future`. The common way this is solved is to
introduce another type, called the promise. If a future is meant to _read_ the value, then the promise is
meant to _write_ the value. By creating two separate objects, we can hand them to the appropriate parties.
Let's see what this would look like.

{% highlight scala linenos %}
class Future[T](private val promise: Promise[T]) {
  def isReady: Boolean = promise.isReady
  def get: T = promise.get
}

class Promise[T] {
  private var result: Option[T] = None

  def future: Future[T] = new Future[T](this)

  // writer functions
  def write(value: T): Unit = this.synchronized {
    this.result = Some(value)
  }

  // reader functions
  def isReady: Boolean = this.synchronized { result.isDefined }
  def get: T = this.synchronized {
    if (!isReady) {
      throw new RuntimeException(
        "Future is not ready yet, no value to get")
    }
    result.get
  }
}
{% endhighlight %}

With this new version we can see that `Future` is now just a read-only interface to our new `Promise` class
and that each future contains a private reference to it's `Promise` pair. The new `Promise` class is mostly
the same as our original `Future` implementation with two exceptions.

  * __1)__ A new `future` method which returns a `Future` object that is paired with the current `Promise` object
  * __2)__ All read and write methods are now contained in `this.synchronized` blocks which synchronizes
           access to the `Promise` object. This is good practice for any object that will be accessed from
           multiple threads.

However, even with this separation of concerns, `Promise` can be written to more than once. Since we've already
synchronized our methods (ensuring no concurrent updates), we can add a simple check to solve our problem.

{% highlight scala linenos %}
class Promise[T] {
  private var result: Option[T] = None
  private var isWritten: Boolean = false;

  // writer functions
  def write(value: T): Unit = this.synchronized {
    if (this.isWritten) {
      throw new RuntimeException(
        "Cannot write value. Already written" )
    }
    this.result = Some(value)
    this.isWritten = true
  }

  // other functions ...
}
{% endhighlight %}



## Part 3 - Handling Failures

Things are shaping up fast for our home-grown future implementation, but there are still some big holes. Notably
we don't have any way to handle failures. Specifically, what happens if there is an exception within the block of
code passed into the future? We can just try-catch that right?

{% highlight scala %}
try {
  val f = future(tp) {
    throw new RuntimeException("sorry!")
  }
} catch {
  case t: Throwable => println("whoops! something went wrong")
}
{% endhighlight %}

I'm sorry, but no. This is never going to work. Why you ask? Well, the `throw` in the above code is actually not
called on the current thread. It is called async on another thread and guess what? That exception will not propagate
to the current thread the above code is executing on. What would actually happen is that future `f` would just
never receive a value because `Promise.write` would never be called.

Well the answer is simple right? Just put the try-catch inside the `Runnable.run` function that `future` creates to
execute the code block. Well, what if an exception occurs, what value do you return? To handle this, we need to
wrap our `T` value in `Future[T]` in a success/fail object.

{% highlight scala %}
trait Try[T]
case class Success[T](value: T) extends Try[T]
case class Failure[T](throwable: Throwable) extends Try[T]
{% endhighlight %}

With these new types, we can now represent the result of a future, previously just `T`, as a `Try[T]`. Of course with
this, we need to update our read and write functions

{% highlight scala linenos %}
class Future[T](private val promise: Promise[T]) {
  def get: Try[T] = promise.get
  // ...
}

class Promise[T] {
  private var result: Option[Try[T]] = None

  def write(value: Try[T]): Unit = // ...

  def get: Try[T] = // ...

  // ...
}
{% endhighlight %}

As well as our `function` function

{% highlight scala linenos %}
def future[T](tp: ThreadPoolExecutor)(block: => T): Future[T] = {
  val promise = new Promise[T]

  // ...

  tp.execute(new Runnable {
    def run(): Unit = {
      try {
        promise.write(Success(block))
      } catch {
        case t: Throwable => promise.write(Failure(t))
      }
    }
  })
  return promise.future
}
{% endhighlight %}

Note that non-relevant parts of code are left out with `// ...` to save space. Now that we are wrapping values into
either a success or failure state and capturing any exceptions, we can now write code like

{% highlight scala %}
val f: Future[String] = future(tp) {
  if (scala.util.Random.nextBoolean()) {
    "I'm running concurrently! whoop!"
  } else {
    throw new RuntimeException("We were unlucky... bummer")
  }
}

val MaxWait = 1000
var i = 0
while (!f.isReady && i < MaxWait) {
  Thread.sleep(5)
  i += 5
}

f.get match {
  case Success(value) => println(value)
  case Failure(t) => t.printStackTrace()
}
{% endhighlight %}

Here we are creating a future which may or may not fail depending on a randomly generated boolean. Once we've waited for
it to complete we access the value with `get` and then use pattern matching (the `match` keyword and a popular feature
of Scala) to either print the returned string or the error trace, depending on the value returned.

## Part 4 - Composing Futures


<!--
  I think this is as "high-level" as I want to go in terms of providing an overview for the rest
  of the post. I think I'll just introduce and implement a new concept in each sub-section
  and eventually we'll build up having _most_ of the functionality of a future.

  I think rather than explain a Future concept (assuming familiarity with Futures already),
  it would be better to introduce the idea in my re-implementaiton and then say "oh, this looks
  like X in Futures"

-->




  [wiki_futr]: https://en.wikipedia.org/wiki/Futures_and_promises
  [wiki_proc]: https://en.wikipedia.org/wiki/Process_(computing)
  [wiki_thrd]: https://en.wikipedia.org/wiki/Thread_(computing)
  [wiki_actr]: https://en.wikipedia.org/wiki/Actor_model
  [wiki_cspc]: https://en.wikipedia.org/wiki/Communicating_sequential_processes
  [scala]: https://en.wikipedia.org/wiki/Communicating_sequential_processes
