---
title: Poor Man's Actors in Java
---


[Actors][actor-wikipedia] are a fantastic way to model concurrency and a much easier mental model
than when working with plain threads and shared memory. However let's say that you're
writing a very simple library that needs to run some simple background tasks. You could
pull in one of the popular Actor implementation libraries out there, but they don't come
for free and can sometimes be heavy-weight.

There is a small movement in the JVM communities to move toward completely self-contained
libraries. I am personally in favor of this movement, but it does mean it can make writing
libraries a touch more difficult. So, if I'm writing a library and I want to do some async
stuff and I _really_ like using actors, what do I do? Well I personally like to program in
the actor model (primarily) for two things

+ Messages are immutable
+ Message passing as a way of communicating

So the question is, can we get this with zero runtime dependencies? Of course we can, but
how much work is it going to be? Let's find out.

## The Exercise

Before we jump right into the meaty bits, we need to setup a problem that our examples will
be trying to solve.
Let's say that I'm writing a library that will do some local file-caching. As part of this,
the library needs to handle _active_ cache expiry. Active meaning that we don't wait until
the value is read again to do the cleanup, meaning we need some sort of asynchronous monitor.


## Immutable Messages

There is nothing stopping from creating immutable data-structures in Java. However it may not be
as easy as using say case classes in Scala. However it is most certainly _possible_. However, this
one is pretty easy to get with very little work on our part.  Java has long had annotation 
processors, which is a way to generate code based on annotations at compile time. You can imagine 
that this is very useful, especially for defining immutable objects. Luckily for us, someone 
has already went through the work to create a generator for immutable data. If you are not 
already familiar, meet [Immutables][imm.io].

Let's define some models that we'll use later

{%highlight java linenos %}
@Value.Immutable
public interface CacheCreated {
  Path getFilePath();
  Long getTtl();
  TimeUnit getTtlUnit();
}

@Value.Immutable
public interface CacheExpired {
  Path getFilePath();
}
{%endhighlight%}

That's it! We now have immutable data-objects that are easy to work with. Let's move on to the Actors.

## Actors

Well we already know we have threads for running concurrent operations, but how do we handle the message
passing? Simple, we define a mailbox that actors receive messages into and process out of. But what is
a mailbox if not just a simple queue. Java has a bunch of those! In fact, there is a nice thread-safe
one that works for us, the [`ConcurrentLinkedQueue`][clq]. So that means we can define an actor as

{% highlight java linenos %}
final ConcurrentLinkedQueue<Object> mailbox = new ConcurrentLinkedQueue<>();

Thread actor = new Thread(() -> {

  while (true) {
    Thread.sleep(10);

    Object msg = mailbox.poll();
    if (msg == null) {
      continue;
    }

    try {
      // process message
    } catch (Exception e) {
      // handle exception(s)
    }
  }

});
actor.start();
{% endhighlight %}

Let's break this down so we understand all that is happening here. First the mailbox

{% highlight java %}
final ConcurrentLinkedQueue<Object> mailbox = new ConcurrentLinkedQueue<>();
{% endhighlight %}

All variables used within lambdas or anonymous inner classes must be effective final, thus the `final`. Note
that we are also typing the collection to `Object`, why? This allows us to send any kind of messages to our
actors and the actors can pattern match to find out what the message is. Since we're in Java, pattern matching
really just means doing a bunch of `instaceof` statements.

{% highlight java %}
while (true) {
  Thread.sleep(10);
{% endhighlight %}

To keep the actor alive, the thread cannot end or be "done." Because of this, we have the thread run in
an infinite loop. However we also don't want our process in a "busy wait." To get around this we sleep for
10ms at the beginning of each loop. 10ms is arbitrary and is just represents the trade-off between using
resources and responding to events in a timely manner.


{% highlight java %}
Object msg = mailbox.poll();
if (msg == null) {
  continue;
}
{% endhighlight %}

Attempt to read the first thing in the mailbox (if anything is there). If there is nothing in the mailbox then
`null` is returned. In this case we simply jump back up to the beginning of the infinite loop which causes us to
sleep for 10ms before checking again.

{% highlight java %}
Object msg = mailbox.poll();
try {
  // process message
} catch (Exception e) {
  // handle exception(s)
}
{% endhighlight %}

For the same reason that we put everything into a `while`, we also need to catch any errors that might occur.
If an exception is thrown, then we need to have code to handle the error and allow the actor to continue
processing. Otherwise the exception could crash our thread and effectively kill our actor. Note that supervision
is not something our implementation has.

# File-Caching Actors

For my system I will define two actors. One actor to receive created events and monitor _when_ cache
items should be expired. This actor will send messages to another actor which will take care of the
actual file deletion.

Putting what we defined above to good use, I can define my actor as

{% highlight java linenos %}
final ConcurrentLinkedQueue<Object> ttlWatcherMailbox = new ConcurrentLinkedQueue<>();
final ConcurrentLinkedQueue<Object> cacheDeleterMailbox = new ConcurrentLinkedQueue<>();
{% endhighlight %}

{% highlight java linenos %}
Thread cacheWatcher = new Thread(() -> {
  Map<Path, DateTime> cacheExpiry = new HashMap<>();
  int count = 0;
  while (true) {
    try {
      count++;
      Thread.sleep(10);

      // check for new items to store
      Object msg = ttlWatcherMailbox.poll();
      if (msg == null) break;
      if (msg instanceof CacheCreated) {
        CacheCreated cc = (CacheCreated) msg;
        cacheExpiry.put(cc.getFilePath(), calculateExpiryDate(cc.getTtl(), cc.getTtlUnit());
      } else {
        // log unhandled message
      }

      // scan cached objects (every 100ms, roughly)
      if (count % 10 != 0) continue;
      for( Map.Entry<Path, DateTime> entry : cacheExpiry.iterator() ) {
        if (isExpired(entry.getValue()) {
          cacheDeleterMailbox.offer(ImmutableCacheExpired.builder()
              .filePath(entry.getValue())
              .build());
        }
      }
    } catch (Exception e) {
      // log out errors
    }
  }
});
{% endhighlight %}

{% highlight java linenos %}
Thread cacheDeleter = new Thread(() -> {
  while (true) {
    try {
      Thread.sleep(10);

      Object msg = cacheDeleterMailbox.poll();
      if (msg == null) continue;
      if (msg instanceof CacheExpired) {
        CacheExpired ce = (CacheExpired) msg;
        deleteFile(ce.getFilePath());
      } else {
        // log unhandled message
      }
    } catch (Exception) {
      // log out errors
    }
  }
});
{% endhighlight %}

{% highlight java linenos %}
cacheWatcher.start();
cacheDeleter.start();
{% endhighlight %}

Bam! We now have simple actors performing our background jobs and communicate by message passing. We
could take this further if wanted and use some of Java's concurrent blocking queues which would give
us back-pressure as well. And like that, there are many small things you could do to add the features
that you most value in a full-blown actor framework / library.

## Improving our API

If we want to take our working code a little bit further we can improve the current API to abstract
some of the details for how this is working. First let's define a central place to create our actors
and store all of our mailboxes. Also, mailboxes should have an address, let's do this by naming our
actors / mailboxes.

{% highlight java linenos %}
class ActorRef {
  private ConcurrentLinkedQueue<Object> mailbox = new ConcurrentLinkedQueue<>();
  private String name;

  public ActorRef(String name) {
    this.name = name;
  }

  public void tell(Object msg) {
    mailbox.offer(msg);
  }

  public Object getLetter() {
    return mailbox.poll();
  }

  public int getLetterCount() {
    return mailbox.size();
  }
}
{% endhighlight %}
{% highlight java linenos %}
class ActorSystem {
  private Map<String, ActorRef> registry = new HashMap<>();

  public ActorRef actor(String name, Consumer<Object> f) {
    ActorRef ref = new ActorRef(name);
    registry.put(name, ref);

    Thread t = new Thread(() -> {
      while (true) {
        if (ref.getLetterCount() == 0) {
          Thread.sleep(10);
        }
        f.accept(ref.getLetter());
      }
    });
    t.start();

    return ref;
  }

  public Optional<ActorRef> lookup(String name) {
    ActorRef ref = registry.get(name);
    return Optional.of(ref);
  }
}
{% endhighlight %}

Modeling this off of Akka, we now have an `ActorRef` which wraps the mailbox and an `ActorSystem` that tracks
all of the actors in our system and also creates some easier utilities for creating actors. We can now define
actors in our system as

{% highlight java linenos %}
ActorSystem system = new ActorSystem();

ActorRef echoActor = system.actor("echo", (Object msg) -> {
  if (msg instanceof String) {
    System.out.println((String) msg);
  }
});

echoActor.tell("Hello, World!");
{% endhighlight %}

and we can handle communication between two named actors as

{% highlight java linenos %}
ActorSystem system = new ActorSystem();

ActorRef ping = system.actor("ping", (Object msg) -> {
  if (msg instanceof String) {
    String sMsg = (String) msg;
    if (sMsg.equals("ping")) {
      System.out.println("ping");
      system.lookup("pong").ifPresent((ActorRef pong) -> pong.tell("pong"));
    }
  }
}
ActorRef pong = system.actor("pong", (Object msg) -> {
  if (msg instanceof String) {
    String sMsg = (String) msg;
    if (sMsg.equals("pong")) {
      System.out.println("pong");
      system.lookup("ping").ifPresent((ActorRef ping) -> ping.tell("ping"));
    }
  }
}
{% endhighlight %}

Sweet! Now we have two actors that can look each other up and communicate back and forth endlessly.
Not that this is a useful example, but it shows out our API improvements work.

Of course you can continue adding little improvements like this until you are eventually building
a full actor implementation (which you shouldn't do). So this brings us to our next question.


## Should You Do This?

So we've seen how we can create some really bare-bones actors but the question really is, "is it
worth it?" The answer to this question depends on what you're doing. If all you need is some very simple
concurrency within your library, then this solution is fantastic as it's zero-dependency. However if
you are performing very complex concurrent tasks that require a lot of coordination or cooperation, then
using a more full-featured framework may be to your benefit. The title did say this was a "poor man's"
implementation, which means we're missing _many_ of the feature that would come in a typical actor
framework / library.

And actually, if you take a look at Akka (a popular Actor framework on the JVM), you'll notice that the
dependency tree is surprisingly small. So, if you _must_ require all the power of a full-blown actor
implementation, at least it's not bloating your dependency tree _too_ much.


{% highlight text %}
sbt> akka-actor/dependencyGraph

             +-------------------+
             |akka-actor_2.11 [S]|
             | com.typesafe.akka |
             |   2.4-SNAPSHOT    |
             +-------------------+
                |          |
                |          -------------
                |                      |
                v                      v
  +---------------------------+ +------------+
  |scala-java8-compat_2.11 [S]| |   config   |
  |  org.scala-lang.modules   | |com.typesafe|
  |           0.7.0           | |   1.3.0    |
  +---------------------------+ +------------+
{% endhighlight %}






  [actor-wikipedia]: https://en.wikipedia.org/wiki/Actor_model
  [imm.io]: http://immutables.github.io
  [clq]: https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ConcurrentLinkedQueue.html

