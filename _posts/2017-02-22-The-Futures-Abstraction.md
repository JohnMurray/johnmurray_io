---
layout:  post
title:   The Futures Abstraction
date:    2017-06-22 12:00:00:00
archive: true
---

<img src="{% base64 blog-files/futures-abstraction/the-future-is-now.jpg %}"
    alt="Future! Credit: https://goo.gl/1oDBfh"/>

Concurrency has many different abstractions: There are the classic
[processes][wiki_proc] and [threads][wiki_thrd], the older but newly-new
[actor-based concurrency][wiki_actr], [CSP style concurrency][wiki_cspc] (looking at you Go),
and the quite popular future/promise. There are more, but one thing they all have in common
is the goal to create a better way to achieve concurrent computation. This is great, if we understand
what we're abstracting.


When it comes to futures, there are a great number of articles online about how to get started using a
particular implementation/framework for futures. However there is a much smaller number of articles
that properly explain what a future is, how they work, and what exactly the abstraction provides you.
This article will walk through those details by implementing futures from the ground-up.

Before we jump right into code, what is the definition of _future_? From [Wikipedia][wiki_futr] we get:

> ... future, promise, delay, and deferred refer to constructs used for synchronizing program execution
> in some concurrent programming languages. They describe an object that acts as a proxy for a result that
> is initially unknown, usually because the computation of its value is yet incomplete.

A future represents the result of some computation, which will eventually yield a result. The “eventually”
bit typically implies that there is some computation that is executing asynchronously (in another
thread, for example) but can also imply a deferred value. You can think of a deferred value as a lazy
value that is not computed until needed. For this article, we will assume that a future is the result
of an async computation. Note that different implementations may use the names “future,” “promise,”
and “deferred” interchangeably and may differ from this post.

Great! Now that we understand what a future is, let’s build our abstraction from the ground-up.

## The Tools

For this post we'll be using [Scala][scala] without any any additional libraries and will only be utilizing
threads for our concurrency. We’ll also make use of some data-structures for sharing values
between threads. Even though I am using Scala, I will avoid any advanced syntax so those unfamiliar
can still (hopefully) follow along.

## Part 1 - Concurrent Computations

Before we can get into the meat of our abstraction, we need to at least be able to execute some code
concurrently, which can be done simply with threads. Using a new thread for each computation looks like:

{% highlight scala %}
val concurrentComputation = new Thread(new Runnable {
  def run(): Unit = {
    println("I'm running concurrently! whoop!")
  }
})

concurrentComputation.start()
{% endhighlight %}

This is fairly simple, but some things are worth pointing out.

  * __1)__ `Unit` means that we didn't return a value (similar to `void` in other languages).
  * __2)__ The `Thread` object does not start executing the `run` function until we call `start()` on line 7.

Despite its simplicity, this is a lot of code to type for each block of code we want to run concurrently.
Let’s rewrite this as a function that we can pass a block of code into. For this article, all code
will live in the `simple.future` namespace.

{% highlight scala linenos %}

package simple.future

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

  * __1)__ `block: => Unit` is a pass-by-name value that returns a `Unit` (not executed until called).
  * __2)__ `block` on line 6 evaluates the user-provided code within the `run` method, which is called
           once the `Thread` is running.
  * __3)__ `{ ... }` is a block of code that is passed to `future` as the first parameter to the function.

Just a quick note on point __#1__: Pass-by-name means that we can pass around blocks of user-code without
actually executing them. Only once we request the “value” from the block (like we do on line 6 above),
is the code executed. This is essential for how our futures execute code asynchronously.

Fantastic! Now we just need to somehow return a result and we’re done, right? Well, not exactly. While
that would get us pretty close to the initial definition, I want to stay a little more grounded and
mimic what a future implementation would do in practice. We’re also missing something from our current
function.

In a real, multi-threaded application there are often multiple operations happening at once; many of
which may be simultaneously using futures. However, not all futures are equally important. For example,
pushing work to a queue that came from a user is arguably more important than flushing metrics to your
metrics store. Currently, we create a thread for each future. It is up to the threads to fight it out
with the JVM/OS scheduler for resources. A better solution would make use of thread pools.

Thread pools are small groups of threads that work is executed on. If there is more work than threads
in the pool, then they are queued up and executed once a thread from the pool is available. We can
control priority within our application by creating larger pools for more important, time-sensitive
work and smaller pools for less important, less critical work.

Let’s rewrite our `future` function to work with a Java thread pool!

{% highlight scala linenos %}
package simple.future

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
  * __2)__ `future` now throws a `RuntimeException` if it is given a `ThreadPoolExecutor` that is not usable.
  * __3)__ `tp.execute(...)` adds work to the thread pool's queue and runs it asynchronously.
  * __4)__ `tp` on line 19 is a thread pool with exactly 4 threads which uses a `LinkedBlockingQueue` as the
           backing queue when there is more work than available threads.

## Part 2 - Returning the Result

We’re quickly working our way towards a future implementation, but currently we don’t have a way to
return a value back to the caller. According to our definition at the beginning, we need to use some
sort of “proxy” object that will eventually contain the value. Let’s define what this proxy object could
look like.

{% highlight scala linenos %}
package simple.future

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

* __1)__ `[T]` is a generic type of `T` to be determined by the user.
* __2)__ `Option` is a type that is either present (`Some`) or absent (`None`).
* __3)__ If the future is not completed, we throw an exception on access.

Now that we have our "proxy" object, we can update our `future` function to return a value using our new
`Future[T]` class.

{% highlight scala linenos %}
package simple.future

def future[T](tp: ThreadPoolExecutor)(block: => T): Future[T] = {
  val fut = new Future[T]

  if (tp.isShutdown || tp.isTerminating || tp.isTerminated) {
    throw new RuntimeException(
      "Cannot execute on threadpool that is not active/running.")
  }
  tp.execute(new Runnable {
    def run(): Unit = {
      // call user-provided code and write result to the future
      val result = block
      fut.write(result)
    }
  })

  return fut
}
{% endhighlight %}

Some quick notes:

  * __1)__ The `block` is now a block of code that evaluates to a type `T`.
  * __2)__ `future` now has type-parameter of `T` and a return type of `Future[T]`.
  * __3)__ The value of the `Future[T]` is written inside the `run` function.

With this newly updated function, we can still call it the same way. The exception is that it now means
something if we capture the result.

{% highlight scala %}
val f: Future[String] = future(tp) { "I'm running concurrently! whoop!" }
{% endhighlight %}

Awesome! We have our proxy object. But the next question becomes, “How do I use it?” If we wanted to
wait on the call we made above for `f`, we might do something like the following:

{% highlight scala %}
val MaxWait = 1000
var i = 0

while (!f.isReady && i < MaxWait) {
  Thread.sleep(5)
  i += 5
}

println(f.get)
{% endhighlight %}

This code is far from ideal, but it works for what we want to do. Later on in this article we’ll get
to more advanced (and more idiomatic) techniques for working with future values.

However, even though this works, there are two issues with this setup: The first is that anyone can
write a value into the future. Ideally this should be hidden as part of the async processing and
separated from the `Future` object. For example, this code should not be valid:

{% highlight scala %}
val f: Future[Int] = future(tp) {
  Thread.sleep(1000)  // sleep future for 1s
  5
}
f.write(6)
println(f.get())  // prints 6

// value of f set to 5 1 second later
{% endhighlight %}

The second issue is that the value is not immutable. Once it is written, it should not be possible
to change the value. As in our example above, once the future stops sleeping, the value would change
to `5`. A future is always the result of a single computation, and that value must never change.

First let’s address the issue that anyone can write into our `Future`. The common way this is solved
is to introduce another type, called the promise. If a future is meant to read the value, then the
promise is meant to write the value. By creating two separate objects, we can hand them to the
appropriate parties. Let’s see what this would look like:

{% highlight scala linenos %}
package simple.future

class Future[T](private val promise: Promise[T]) {
  def isReady: Boolean = promise.isReady
  def get: T = promise.get
}

class Promise[T] {
  private var result: Option[T] = None

  lazy val futurePair: Future[T] = new Future[T](this)

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

With this new version we can see that `Future` is now just a read-only interface to our new `Promise`
class, and that each future contains a private reference to its `Promise` pair. The new `Promise` class
is mostly the same as our original `Future` implementation with two exceptions:

  * __1)__ A new `futurePair` value which creates a `Future` object that is paired with the current `Promise`
           object. This is only generated when needed (thus the `lazy` part).
  * __2)__ All read and write methods are now contained in `this.synchronizedblocks`, which synchronizes access
           to the `Promise` object. This is good practice for any object that will be accessed from multiple
           threads.

However, even with this separation of concerns, `Promise` can be written to more than once. Since we’ve
already synchronized our methods (ensuring no concurrent updates), we can add a simple check to solve
our problem:

{% highlight scala linenos %}
package simple.future

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

We can now return values from futures, but what happens if the computation fails and we throw an
exception? How do we handle that? What value is returned for the future?

Well exceptions are easy, we can just use a try-catch block for that, right?

{% highlight scala %}
try {
  val f = future(tp) {
    throw new RuntimeException("sorry!")
  }
} catch {
  case t: Throwable => println("whoops! something went wrong")
}
{% endhighlight %}

I'm sorry, but no. This is never going to work.

<img src="{% base64 blog-files/futures-abstraction/nope.jpg %}"
    alt="Future! Credit: https://goo.gl/VWghzJ"/>

Why you ask? Well, the `throw` in the above code is actually not called on the current thread.
Remember that the code in `block` is not evaluated until called within the `Runnable.run` method. It
is called asynchronously on another thread — and guess what? That exception will not propagate to
the current thread the above code is executing on. What would actually happen is that future `f` would
just never receive a value because `Promise.write` would never be called.

Well the answer is simple right? Just put the try-catch inside the `Runnable.run` function that `future`
creates to execute the code block. Well, what if an exception occurs, what value do you return? To
handle this, we need to wrap our `T` value in `Future[T]` in a success/fail object:

{% highlight scala %}
package simple.future

trait Try[T]
case class Success[T](value: T) extends Try[T]
case class Failure[T](throwable: Throwable) extends Try[T]
{% endhighlight %}

With these new types, we can now represent the result of a future, previously just `T`, as a `Try[T]`.
Of course with this, we need to update our read and write functions:

{% highlight scala linenos %}
package simple.future

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

As well as our `future` function:

{% highlight scala linenos %}
package simple.future

def future[T](tp: ThreadPoolExecutor)(block: => T): Future[T] = {
  val promise = new Promise[T]

  // omitted code

  tp.execute(new Runnable {
    def run(): Unit = {
      try {
        // call user-provided code and write result to the future
        val result = block
        promise.write(Success(result))
      } catch {
        case t: Throwable => promise.write(Failure(t))
      }
    }
  })
  return promise.futurePair
}
{% endhighlight %}

Now that we are wrapping values into either a success or failure state and capturing any exceptions,
we can now write code like:

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
  case Failure(t)     => t.printStackTrace()
}
{% endhighlight %}

Here we are creating a future which may or may not fail, depending on a randomly generated boolean.
Once we’ve waited for it to complete, we access the value with `get` and then use pattern matching
(the `match` keyword and a popular feature of Scala) to either print the returned string or the
error trace, depending on the value returned.

## Part 4 - Async Access

To recap what we've created so far:

  * A `future` method that takes a block of code, executes on a thread-pool, and returns a `Future`.
  * `Future` class for reading values, and a `Promise` for writing values.
  * `Try[T]` to represent success and failure values from our asynchronously executed code-block.

This is a good start to creating a realistic implementation of futures. However, there are still some
very big holes. Namely, accessing the final value leaves a lot to be desired. Currently to get the
value we have to block on the current thread and wait for the future to be completed.

The easy way to not block is to provide callback functions. Callbacks are user-provided blocks of code
that are registered with the `Future` object and called once the `Future` is ready. We’ll define three
functions: `onComplete`, `onSuccessand` `onFailure`. Let’s start first with `onComplete`:

{% highlight scala linenos %}
package simple.future

class Future[T](private var promise: Promise[T]) {
  // ...

  def onComplete(tp: ThreadPoolExecutor)(f: Try[T] => Unit): Unit = {
    promise.registerOnComplete(tp, f)
  }
}

class  Promise[T] {
  // ...

  var onCompleteHandlers: List[(ThreadPoolExecutor, Try[T] => Unit)] = Nil

  def registerOnComplete(tp: ThreadPoolExecutor, f: Try[T] => Unit): Unit = {
    // add 2-tuple of thread-pool and function to list
    onCompleteHandlers ::= (tp, f)
  }

  def callOnCompletes(value: T): Unit = {
    for (handler <- onCompleteHandlers) {
      val tp: ThreadPoolExecutor = handler._1
      val f:  Try[T] => Unit     = handler._2

      future(tp) {
        f(value)
      }
    }
  }

  def write(value: Try[T]): Unit = this.synchronized {
    if (this.isWritten) {
      throw new RuntimeException(
        "Cannot write value. Already written")
    }
    this.result = Some(value)
    this.isWritten = true
    this.callOnCompletes(value)
  }
}
{% endhighlight %}

We now have a new method on `Future` of `onComplete` which registers a callback handler with `Promise`.
The reason that `Promise` handles the firing of the callback is because it maintains the relationship
that `Future` is read-only and that `Promise` is the write interface. With this, we can fire the callbacks
as soon as `Promise.write` is called.

Some final notes about the above code:

  * __1)__ `onCompleteHandlers` is a list of 2-tuples containing the thread pool and the block of code to execute on the
           result. It is also initialized to an empty list (`Nil`).
  * __2)__ The code `onCompleteHandlers ::= (tp, f)` appends a 2-tuple to the list `onCompleteHandlers`.
  * __3)__ Values in 2-Tuples are accessed by `x._1` and `x._2` as on line 23 and 24.

And we can now use our new function like:

{% highlight scala %}
val f: Future[String] = future(tp) {
  if (scala.util.Random.nextBoolean()) {
    "I'm running concurrently! whoop!"
  } else {
    throw new RuntimeException("We were unlucky... bummer")
  }
}

f.onComplete(tp) { res: Try[String] =>
  res match {
    case Success(value) => println(value)
    case Failure(t)     => t.printStackTrace()
  }
}
{% endhighlight %}

With this, we could easily imagine how to write other functions such as `onSuccess`, `onFailure`, etc.

## Part 5 - Composing Futures

Callbacks are an excellent way to access data retrieved/generated from an asynchronous operation.
However, what if we wanted to combine the value from two async operations, or we wanted to transform
the result of an async operation, but still maintain a future to that transformed value in the current
thread? This is where futures really shine: The ability to combine the result of multiple futures
together.

To achieve this, we need to have callbacks that return yet another `Future` as a proxy object to a
result of the callback. The first function we’ll look at is map with the following signature:

{% highlight scala %}
class Future[T](...) {
  def map[U](tp: ThreadPoolExecutor)(f: T => U): Future[U]
}
{% endhighlight %}

`map` takes a thread pool and a function and returns another future. The user-provided function, `f`,
takes as a parameter a successful value from the current future and returns a value of type `U`.
However `map` returns a value of type `Future[U]`. This allows us to call `map` on a `Future` that may or
may not be completed. This means that we can’t return the result of our transformation (`f`) directly,
but must use another `Future`. This is best explained with some examples:

{% highlight scala %}

// base future we'll be map'ing
val f: Future[Int] = future(tp) {
  Thread.sleep(2000)  // sleep 2 seconds
  2
}

// multiply f by 10
val f10: Future[Int] = f.map(tp) { two => two * 10 }

// turn into a string
val fs: Future[String] = f.map(tp) { two => two.toString }
{% endhighlight %}

Because `f` takes at least 2 seconds to run, you can see why we can’t immediately apply our
transformations to the value. Instead we use `map` to defer the transformations for when the future
has completed, but we can still hold onto a proxy object representing the result of those
calculations.

But what happens if the future being mapped fails? In that case the error propagates to all failed
values:

{% highlight scala %}
val f: Future[Int] = future(tp) {
  Thread.sleep(2000)
  throw new RuntimeException("whoops!")
}

val f10: Future[Int] = f.map(tp) { value => value * 10 }

f10.onComplete(tp) { res: Try[Int] =>
  res match {
    case Success(value) => // do nothing
    case Failure(t)     => t.printStackTrace()
  }
}
{% endhighlight %}

The above code would print out a stacktrace for `f10`. The stacktrace would say “whoops!” and would
be the same exception from `f` passed along to `f10`. This makes sense, as we cannot transform an
exception as if it were a successful value.

Enough examples, let’s take a stab at implementing `map`:

{% highlight scala linenos %}
package simple.future

class Future[T](...) {
  def map[U](tp: ThreadPoolExecutor)(f: T => U): Future[U] = {
    promise.map(tp)(f)
  }
}

class Promise[T] {
  def map[U](tp: ThreadPoolExecutor)(f: T => U): Future[U] = {
    val mapPromise = new Promise[U]
    // create onComplete block that calls user-function (f) on success
    // and passes through exceptions on failure
    val block: Try[T] => Unit = { res: Try[T] =>
      res match {
        case Success(v) => futureWithPromise(tp, mapPromise) {
          f(v)
        }
        case Failure(t) => mapPromise.write(Failure(t))
      }
    }
    registerOnComplete(tp, block)

    return mapPromise.futurePair
  }
}
{% endhighlight %}

You can see that we are defining this on `Promise`. This is because `Promise` is our writable interface
and we want to take advantage of the `registerOnCompletefunction` we saw earlier. `map` works by creating
a new promise/future pair and returning the future immediately. However the callback that is
registered allows us to call our user-provided function `f` in the callback and write the result to the
new promise/future pair we created. For failures we can see the write happening:

{% highlight scala %}
  case Failure(t) => mapPromise.write(Failure(t))
{% endhighlight %}

This allows us to propagate failure and by-pass the user-provided code which expects a value. This
allows us to call map without having to worry about additional error handling.

But wait, what is this `futureWithPromise` function, and what does it do? Remember `future` from earlier
that takes a block of user code and a thread pool and returns a future? Well this is pretty much the
same thing except that it takes a pre-created promise object. With this, we can re-define our
`future` method as well (to avoid duplication) and we get:


{% highlight scala linenos %}
package simple.future

def futureWithPromise[T](tp: ThreadPoolExecutor, promise: Promise[T])
                        (block: => T): Future[T] = {
  if (tp.isShutdown || tp.isTerminating || tp.isTerminated) {
    throw new RuntimeException(
      "Cannot execute on threadpool that is not active/running.")
  }
  tp.execute(new Runnable {
    def run(): Unit = {
      try {
        // call user-provided code and write result to the future
        val result = block
        promise.write(Success(result))
      } catch {
        case t: Throwable => promise.write(Failure(t))
      }
    }
  })

  return promise.futurePair
}

def future[T](tp: ThreadPoolExecutor)(block: => T): Future[T] = {
  val promise = new Promise[T]

  return futureWithPromise(tp, promise)(block)
}
{% endhighlight %}

We can see that `futuerWithPromise` is basically our previous implementation of future and future is
now just a convenience method for when you don’t have your own Promise already created.

### So much more!

When it comes to composing futures, there is often a myriad of functions available to transform futures
in different ways. For example, these two functions are very common (although the naming may differ
across implementations):

{% highlight scala %}
class Future[T](...) {
  def flatMap[T](tp: ThreadPoolExecutor)(f: T => Future[U]): Future[U]

  def recover(tp: ThreadPoolExecutor)(f: Throwable => T): Future[T]
}
{% endhighlight %}

`flatMap` is very much like our `map`, but this allows the user-provided code to return a `Future[U]`
instead of just a `U`. Think of making a web-request which returns a future, and then using the result
of the first web-request to make a second web-request. For this case you would use a `flatMap`.

`recover` is a way to not only handle a failed future, but also provide/calculate some sort of default
value. Imagine making a web-request and, assuming it fails, using recover to provide a cached result.
When combining recover with other compositing functions like map and `flatMap`, we can define a future
with all of our transformations and error handling in a declarative way.

Since you’ve seen the basic format for implementing these type of functions (with the `map` example),
I’ll leave it as an exercise to the reader (you) to define `flatMap` and `recover`.


## Conclusion

That was quite a bit of work! This is still a very bare-bones, basic implementation of futures but,
it should be enough to give us some solid ground to stand on for understanding futures, and hopefully
understanding why this is a useful (in my humble opinion) and popular abstraction. If you’re interested
in what a real-world future implementation looks like, check out some of the links below (note that
this post most closely mimics the API of the Scala implementation):


  * [Scala Library](http://docs.scala-lang.org/overviews/core/futures.html)
  * [Rust](https://tokio.rs/docs/getting-started/futures/)
  * [C++ stdlib](http://en.cppreference.com/w/cpp/thread/future)
  * [Java 8](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html)
  * [C#](https://msdn.microsoft.com/en-us/library/ff963556.aspx)
  * [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)

<!--

TODO: link these things

Link to some various future implementations to read / learn more
  - Scala impl  (stdlib versions)
  - rust impl?  (if there is a good one to link to)
  - C++ impl    (stdlib ones)
  - Java impl   (java 8 completable futures)
  - Ruby impl   (celluloid?)

-->



  [wiki_futr]: https://en.wikipedia.org/wiki/Futures_and_promises
  [wiki_proc]: https://en.wikipedia.org/wiki/Process_(computing)
  [wiki_thrd]: https://en.wikipedia.org/wiki/Thread_(computing)
  [wiki_actr]: https://en.wikipedia.org/wiki/Actor_model
  [wiki_cspc]: https://en.wikipedia.org/wiki/Communicating_sequential_processes
  [scala]: https://en.wikipedia.org/wiki/Communicating_sequential_processes
