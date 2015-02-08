---
layout: post
title:  "Scala map() vs map{}"
date:   2013-11-17 12:00:00
---

I was wondering the other day what the difference really was, in Scala, between

{% highlight scala linenos %}
val list = List(1, 2, 3, 4)
list.map(x => x * x)
{% endhighlight %}

and

{% highlight scala linenos %}
val list = List(1, 2, 3, 4)
list.map { x => x * x }
{% endhighlight %}

So, I figured I'd take a look at the map function defined on the List class. I winded up
finding the definition in the `TraversableLike` trait as follows:

{% highlight scala linenos %}
def map[B, That](f: A => B)(implicit bf: CanBuildFrom[Repr, B, That]): That = {
  def builder = { // extracted to keep method size under 35 bytes, so that it can be JIT-inlined
    val b = bf(repr)
    b.sizeHint(this)
    b
  }
  val b = builder
  for (x <- this) b += f(x)
  b.result
}
{% endhighlight %}

Let's ignore the builder for now since it's the less important part of this question. We're
interested in the first set of parameters, `f: A => B`. This seems to be a normal argument
yet we can apply it in two different ways. That got me thinking a little bit and so I decided
to play around a bit to see if I can figure this out anecdotally, before looking up the proper
literature.

### Non-Function Arguments

I first wanted to try with some simple functions that didn't have functions as arguments to see if
this format is generally applicable. I came up with some simple tests.

{% highlight scala linenos %}
def echo(x: String) = println(x)
 
echo{"hello"}    // valid
echo("hello")    // valid
 
 
def echoName(name: String, x: String) = println("$name: $x")
 
echoName{"John", "hello"}        // invalid
echoName("John", "hello")        // valid
echoName({"John"}, {"hello"})    // valid
{% endhighlight %}

So from this it seems to indicate that braces are not interchangeable with parenthesis. However,
it does seem that `"John"` and `{"John"}` are interchangeable. In fact, if we look at the REPL
we see:

{% highlight scala linenos %}
val s1 = {"hello"}     // s1: String = hello
val s = "hello"        // s: String = hello
{% endhighlight %}

This may not be a surprise to some, but that means that something like `echo {"hello"}` can
really just be thought of as a shorthand for `echo({"hello"})`. But what about `{x => x * x}`.
We can assume that just returns a function, correct? So that would means we can assume that
these are functionally equivalent:

{% highlight scala linenos %}
val list = List(1, 2, 3, 4)
list.map(x => x * x)
list.map({x => x * x})
{% endhighlight %}

And, anecdotally, this seems to be true.

### Back to Functions

So based on our findings, what is the point of the curly braces and when would they be useful.
Let's do some experiments with a little more meat and see if we can find an answer. First let's try
a slightly larger map example.

{% highlight scala linenos %}
val list = List(1, 2, 3, 4)
 
// not valid (compile-error)
list.map(x =>
  val y = x * x
  val z = y * x
  Math.sin(z / x)
)
 
// valid
list.map{x =>
  val y = x * x
  val z = y * x
  Math.sin(z / x)
}
{% endhighlight %}

Ah ha, so there is a good reason to use curly braces. It looks like the parenthesis version cannot
handle multiple statements and is only expecting a single expression. Furthermore, I found this bit
interesting as well:

{% highlight scala linenos %}
val f1 = (x : Int => x * x)    // invalid - compiler error (can't resolve x)
val f2 = (x : Int) => x * x    // valid
val f3 = {x : Int => x * x}    // valid
{% endhighlight %}

The same syntax using parenthesis cannot be used to define the function outside of the map unlike
the version with curly-braces. Very interesting.

### The Real Story

Okay, at this point I feel like I've made some interesting findings, but I'm curious what the
Internet has to say about such things. So I figured I'd let her weigh in. I came across a few
different posts:

+ [Scala Forums Posting, complete with appearance by Odersky][1]
+ [This SO Post][2]
+ [Another Scala Forums Posting][3]

Surprisingly, all three answers were by the same person. For someone strapped for time when it
comes to blogging, he sure does seem to make a lot of appearances on this topic. ;-D

All in all, there seems to be quite a bit of discussion with some grey areas still that I still
don't fully understand. In those cases the compiler seems to be the specification, which is never
preferable (IMO) for many reasons. Oh Scala, you are an interesting little language.


  [1]: http://www.scala-lang.org/old/node/2593
  [2]: http://stackoverflow.com/questions/4386127/what-is-the-formal-difference-in-scala-between-braces-and-parentheses-and-when
  [3]: http://www.scala-lang.org/old/node/10195
