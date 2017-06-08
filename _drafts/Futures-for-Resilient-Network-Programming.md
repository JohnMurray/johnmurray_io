---
title: Futures for Resilient Network Programming
---

<!-- Summary - Introduction to the article -->
In the JVM ecosystem, with the introduction of libraries such as [NIO][nio] and [Netty][netty],
there is a push for developers and
library writers to use asynchronous I/O. In the Scala ecosystem, this usually involves the use of
`Future`s to represent return values that are not yet computed. Although the `Future` allows us to
specify transformations and compositions over future data values it is not always clear how to build
fault tolerant code which may include retries, backoffs, and other standard techniques for resilient
code. This post explores how `Future`s in Scala can be used to write resilient network code.

## What are Futures

While [there][fut1] [are][fut2] [many][fut3] [resources][fut4] [available][fut5] to better learn
what `Futures` are (and I do recommend reading some of these if you are not familiar before continuing),
the quick and dirty definition of a future is

> The Future monad is a container that holds the result of a concurrent computation, and information about
> whether it succeeded or failed.  — [Kevin Lim][lets_talk_about_kevin]

The last point here is important when dealing with network code as every operation could potentially fail.
Networks are unreliable, tricky beasts that stop working when you least expect. Representing failure and,
more importantly, providing a model for handling failures is a necessary part of network programming.

If you are unfamiliar with `Future`s in Scala, but are determined to read on, consider this a quick-ref
guide for the rest of the article. Otherwise, feel free to skip on to the next section __The Search Index__.

#### Future Quick-Ref
{% highlight scala %}
// Methods for Future[T], where T is some generic type

/* map(f: T => TransformedType): Future[TransformedType]
 *   Applies a lambda to the inner type of the future. Only applies to succeeded futures */
val onePi: Future[Double] = Future[Int](1).map(intValue => intValue * 3.14d)

/* flatMap(f: T => Future[TransformedType]): Future[TransformedType]
 *   Applies a lambda to the inner type of future and returns a future. Useful for
 *   composing multiple futures together. */
def longComputation(): Int
def longComputation2(x: Int): Double

val chainedComputations: Future[Double] = longComputation().flatMap { computedInt =>
  longComputation2(computedInt)
}

/* recover(f: Throwable => T): Future[T]
 *    Applies a function that takes an error (from a failed future) and returns a T.
 *    Useful for specifying default values when encountering an error */
val defaultInt = Future[Int]({
    throw new RuntimeException("whoops")
  }).recover {
    case t: Throwable => 5
  }

/* recoverWith(f: Throwable => Future[T]): Future[T]
 *    recovers version of flatMap. Takes the error, for a failed future, and returns
 *    a future of the same type. Useful for simplistic retry. */
def longComputation(): Future[Double]

val computedValue = longComputation().recoverWith({ case t: Throwable =>
    // ignore error, retry
    longComputation()
  })
{% endhighlight %}

One additional note is that when calling methods such as `map`, the lambda provided is only
called if the `Future` is successful. Additionally, the opposite is true for methods like
`recover`.

## The Search Index

To better understand how to apply the ideas presented in this post, we'll use the following scenario.
There is a search index that we need to update and occasionally read from. While inserts are very expensive,
lookups are very cheap. The index is updated and queried over an HTTP interface. The following defines our
interface to an HTTP library:

{% highlight scala linenos %}
trait HttpClient {
  def url(u: String): HttpRequest
}
trait HttpRequest {
  def withBody(b: String): HttpRequest
  def withHeader(h: (String, String)): HttpRequest
  def withQueryString(q: (String, String)): HttpRequest

  def get: Future[HttpResponse]
  def put: Future[HttpResponse]
  def post: Future[HttpResponse]
  def delete: Future[HttpResponse]
}
trait HttpResponse {
  def statusCode: Int
  def body: String
}
{% endhighlight %}

As you can see, our network (HTTP) library returns a `Future[T]` for all operations that involve
the network. The code we'll be building in this post is a library to interact with this search
index, built on top of our HTTP client. We start with this basic building block.

{% highlight scala linenos %}
class SearchIndexClient(baseUrl: String, http: HttpClient) {
  /** Query the search index*/
  def search(query: String): Future[Seq[String]] = {
    http.url(s"$baseUrl/search").withQueryString("q" -> query).get.map { resp =>
      // multiple results separated by ;;
      resp.body.split(";;")
    }
  }

  def lookup(documentId: Int): Future[Option[String]] = {
    http.url(s"$baseUrl/document/$documentId").get.map { resp =>
      if (resp.statusCode != 200) None
      else Some(resp.body)
    }
  }

  /** Insert a document and return the ID */
  def insert(document: String): Future[Int] = {
    http.url(s"$baseUrl/document").withBody(document).post.map { resp =>
      if (rep.statusCode != 201) {
        throw IndexInsertException(s"Could not insert into index: ${resp.body}")
      } else {
        resp.body.toInt
      }
    }
  }
}

// parent for search-index related exceptions
abstract class SearchIndexException(val msg: String, val cause: Throwable = null)
    extends Exception(msg, cause)

case class IndexInsertException(msg: String, cause: Throwable = null)
    extends SearchIndexException(msg, cause)
{% endhighlight %}

## Basic Retries

While the network is unreliable, the issues seen may also be transient (short lived)
issues. This could be anything from an unreachable host to a DNS resolution error. The
main point is you don't want to stop trying at the first sight of an error; you need
to retry your operation and possibly more than once.

As you may have already guessed, we can get basic retry functionality by using `recoverWith`.
Let's rewrite the `search` method of our API client to use `recoverWith` to handle some possible
network I/O errors.

{% highlight scala linenos %}
class SearchIndexClient(baseUrl: String, http: HttpClient) {
  def search(query: String): Future[Seq[String]] = {
    def get = http.url(s"$baseUrl/search").withQueryString("q" -> query).get

    get.recoverWith({
      case e @ (_ : InterruptedIOException | _ : IOException) =>
        // log exception 'e', begin retry
        get
      case notHandled =>
        // re-throw any other exception that we encounter
        throw notHandled
    }).map { resp =>
      // multiple results separated by ;;
      resp.body.split(";;")
    }
  }

  // rest of code
}
{% endhighlight %}

The `search` method now handles general and aync-related (via `InterruptedIOException`) exceptions and
will retry one time. However, what if we want to have more than one retry? Do we continue to nest
`recoverWith` invocations? Luckily for us `recoverWith` returns a new `Future[T]` object. Meaning we
can rewrite our code like the following.

{% highlight scala linenos %}
class SearchIndexClient(baseUrl: String, http: HttpClient) {
  val numRetries = 3

  def search(query: String): Future[Seq[String]] = {
    def get = http.url(s"$baseUrl/search").withQueryString("q" -> query).get

    var httpResult = get
    for (_ <- 1 until numRetries) {
      httpResult = httpResult.recoverWith({
        case e @ (_ : InterruptedIOException | _ : IOException) =>
          get
        case notHandled => throw notHandled
      })
    }

    httpRes.map { resp =>
      // multiple results separated by ;;
      resp.body.split(";;")
    }
  }

  // rest of code
}
{% endhighlight %}

<!-- using recoverWith -->

## Retries with Backoff

<!-- Making a future wait -->
<!-- Thread.sleep is bad -->
<!-- great place for visuals of a thread-pool and what it looks like to sleep (threads become blocked, reduced capacity) -->
<!-- use akka, but ideally stdlib. Links for handy akka funcitons: https://gist.github.com/viktorklang/9414163 -->

## Verifying Before Retrying

<!-- use our long-running example of inserting into a search index as an example (looksups are cheap, inserts are expensive) -->

## Waiting on Remote Processes
 <!-- waiter util for waiting on remote processes -->
 <!-- this feels fairly different from the rest as a cohesive pattern -->
 <!-- can also be mixed into the rest of this -->
 <!-- THOUGHT: conceptually this has retries + verifiers (smart retries) built in. Should re-use code if possible -->

## Putting it all Together

<!-- general form / solution -->
<!-- tie into AN products (Geo Manager) -->





# Original Opening
<!-- original pass at article opening, may be able to re-use some of it -->
If you work with [`Future`s][fut] in [Scala][scala], you may have found yourself needing to "wait" or
"pause" what you are doing. But when you are working with a series of Futures (async all the things!)
what do you do?

Let's say that I have a series of tasks to run. These tasks are doing some I/O operations and all return
`Future`s. The next task cannot be run until the previous task completes. So first pass you get something
like

    {% highlight scala %}
    for {
      t1 <- taskOne()
      t2 <- taskTwo(t1)
      t3 <- taskThree(t2)
      t4 <- taskFour(t3)
      t5 <- taskFive(t4)
    } yield {
      t5
    }
    {% endhighlight %}


What happens if `taskTwo` fails? Well, you'll likely read online that your error will "fall through" and the code
above will result in a failed future. While that is correct, it's not entirely useful. More likely you're
interested in how to recover from that situation. In that case you may just want to retry. Let's turn `taskTwo(t1)`
into a safer method.

    {% highlight scala %}
    {% endhighlight %}


  [fut1]: http://docs.scala-lang.org/overviews/core/futures.html
  [fut2]: http://doc.akka.io/docs/akka/current/scala/futures.html
  [fut3]: http://danielwestheide.com/blog/2013/01/16/the-neophytes-guide-to-scala-part-9-promises-and-futures-in-practice.html
  [fut4]: http://code.hootsuite.com/introduction-to-futures-in-scala/
  [fut5]: http://alvinalexander.com/scala/concurrency-with-scala-futures-tutorials-examples
  [lets_talk_about_kevin]: http://code.hootsuite.com/co-ops/kevin-lim/
  [netty]: https://netty.io/
  [nio]: https://docs.oracle.com/javase/8/docs/api/java/nio/package-summary.html
