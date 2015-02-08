---
layout: post
title:  "Getting Started with Akka"
date:   2013-08-31 12:00:00
---


For those not familiar, [Akka][1] is a [Scala][3] library for implementing the
[Actor Model][2]. Technically you can use Java as well, but things are a little
more concise and idiomatic in Scala.

Let's get started shall we. The first thing you should have installed is [sbt][4].
Then you'll want to create a new folder for your project `hello-akka`. Within that
folder, let's create a `build.sbt` file with the following contents:

<!-- build.sbt gist -->
{% highlight text linenos %}
name := "Hello Akka"
 
version := "0.0.1"
 
scalaVersion := "2.10.2"
 
resolvers += "Typesafe Repository" at "http://repo.typesafe.com/typesafe/releases/"
 
libraryDependencies += "com.typesafe.akka" %% "akka-actor" % "2.2.0"
 
libraryDependencies += "com.typesafe.akka" %% "akka-kernel" % "2.2.0"
{% endhighlight %}

You can see that we just have some basic setup with names and versions. You'll also
notice that we're delcaring `akka-actor` and `akka-kernel` as our dependencies. The
main library is `akka-actor` which we will (obviously) define our actor in. The second
is a little less obvious, `akka-kernel`, and will be used to define our akka-instance
as a standalone setup (not as a library within another project).

The next thing we want to do is create a couple of actors to perform an asynchronous
hello-world:

{% highlight scala linenos %}
import akka.actor.{Actor, Props}
 
object HelloWorldActor {
  case object Tick
}
 
class HelloWorldActor extends Actor {
  val greeter = context.actorOf(Props[Greeter], "greeter")
 
  def receive: Actor.Receive = {
    case HelloWorldActor.Tick => greeter ! Greeter.Greet
  }
}
{% endhighlight %}

{% highlight scala linenos %}
import akka.actor.Actor
 
object Greeter {
  case object Greet
}
class Greeter extends Actor {
  def receive = {
    case Greeter.Greet => {
      println("Hello, World")
    }
  }
}
{% endhighlight %}

Take note that these files were created within the directory `src/main/scala` within
the `hello-akka` directory. From the above, you'll notice that the HelloWorldActor
receives a `Tick` event and then sends a message to the `Greeter` actor which then
prints `"Hello, World"`. You may be wondering what is sending the `Tick` event to the
HelloWorldActor to start with. For this we have to define our kernel:

{% highlight scala linenos %}
import akka.actor.{ActorSystem, Props}
import akka.kernel.Bootable
import scala.concurrent.duration._
 
class HelloWorldKernel extends Bootable {
  val system = ActorSystem("helloworldkernel")
  import system.dispatcher
 
  def startup() {
    val helloWorldActor = system.actorOf(Props[HelloWorldActor])
    system.scheduler.schedule(0 milliseconds,
      500 milliseconds,
      helloWorldActor,
      HelloWorldActor.Tick)
  }
 
  def shutdown() {
    system.shutdown()
  }
}
{% endhighlight %}

This is the entry-point for our application. You can see that we are creating an instance
of the `HelloWorldActor` and scheduling a message be sent (`Tick`) every 500 milliseconds.

## Done!

That's all there is to creating a standalone Akka, pretty simple. There are various ways you
can run your application, but I feel the easiest is with scripts that ship with Akka. To add
that to your project, run the following script from within the `hello-akka` directory:

{% highlight bash linenos %}
wget http://downloads.typesafe.com/akka/akka-2.2.1.tgz
tar xzf akka-2.2.1.tgz
mv akka-2.2.1 akka
rm akka-2.2.1.tgz
dos2unix akka/bin/akka
{% endhighlight %}

I typically create a Makefile for running my project just because I find that easier. You could
do something like the following:

{% highlight make linenos %}
all: build deploy
run: build deploy start
 
build:
  sbt package:clean
  sbt package
 
start:
  ./akka/bin/akka HelloWorldKernel
 
deploy:
  mv target/scala-2.10/hello-akka_2.10-0.0.1.jar akka/deploy/
{% endhighlight %}

And then just run `make run` to start your project. You should see something like the following:

{% highlight text linenos %}
Starting Akka...
Running Akka 2.2.0
Deploying file:/Users/jmurray/IdeaProjects/HelloAkka/akka/deploy/hello-akka_2.10-0.0.1.jar
Starting up HelloWorldKernel
Successfully started Akka
Hello, World
Hello, World
Hello, World
Hello, World
...
{% endhighlight %}



  [1]: http://akka.io
  [2]: http://en.wikipedia.org/wiki/Actor_model
  [3]: http://scala-lang.org
  [4]: http://www.scala-sbt.org/0.12.4/docs/Getting-Started/Setup.html
