---
title: Go - Futures
---

### Premise

Go is great. Futures are great. Go doesn't have futures.

### Motivation

Go's concurrency model is based on go-routines and channels which is
very similar (excluding I/O handling and automatic polling which is
freaking amazing) to using threads with a thread-safe queue for
communication.

Futures offer a different model of concurrent computation that allows for
composable operations (you can think pipelines or streams if you like) that
are typically stateless. Composability, the primary differentiator in my
biased opinion, is the primary reason why futures may be a better choice
over go-routines for particular workflows.

If you are unfamiliar with the mechanics of Futures or how they could be
implemented, I have [another post][john_io_future] that gives an in-depth
explanation by building a basic implementation from scratch and explains
all the decisions along the way.

### Defense

Since this is written with a Go audience in mind I feel a little defensive
writing may be necessary. So... the disclaimer:

> This is in no way a disparagement of go-routines
> or channels. I just believe that the multiple models for concurrency all
> have their place and that there is not just one hammer for all the screws.

Also, yes I have seen other posts and/or projects to implement futures in Go
but, to me, they seem incomplete. This post aims to dig deeper and be more
complete on the subject than I have seen elsewhere. If you feel you have
already seen this horse and pony show before, you are under no obligation to
keep reading.

### TL;DR

I built an implementation of the future abstraction in Go. The implementation
is composable in a type-safe way via the use of code-generation. The code
is available for perusal/use on my GitHub [here][github_bastard_go_future].

### Defining Futures

Before we can start building, there need to be some definition of what we're
building. We don't need to be super strict, but in general a solution should
have the following:

+ Asynchronous execution of code
+ All futures result in a value (otherwise `go someFunc()` is good enough)
+ Future results are transformable
+ Futures can be combined with other future (i.e. composability)
+ Futures are executed within a bounded context (controllable concurrency)

Some secondary goals that would be nice

+ Futures are cancellable
+ Cancellation cascades
+ Everything is type-safe (no `interface{}`)

The last secondary goal to make everything type-safe requires some code-generation
so we'll leave that to last so we can work in plain Go code first.

In general (sans secondary goals), I'd like an API that looks like this:

{% highlight go %}
poolSize := 5
bufferSize := 100

sc := future.NewScheduler(poolSize, bufferSize)

// runs async
mathRes := future.New(sc, func() interface{} {
  return 2 + 2
})

// transform with 2nd future on success
mathRes2 := mathRes.FlatMap(sc, func(value interface{}) interface{} {
  return value.(int) + 2
})

// transforms on successful completion
stringRes := mathRes2.Map(func(value interface{}) interface{} {
  return fmt.Sprintf("value: %d", value.(int))
})

// provide default value on failed future
finalRes := stringRes.Recover(func(err error) interface{} {
  return "value: 0"
});
{% endhighlight %}

### The Foundation - Schedulers

__TL;DR;__

Schedulers allow us to control how our futures are run and are akin to
thread pools in other languages. We've defined a simple interface to
allow multiple scheduler types to be plugged in.

Skip forward to [The Promise, the Future](#the-promise-the-future)

__Long Version__

In order to execute futures concurrently __and__ within a bounded context,
we need to introduce the idea of a scheduler. _Hold up there hoss, what is
a bounded context?_ Oh, I'm glad you asked imaginary second personality. A
bounded context is just a way to limit the amount of resources that a set
of futures is allowed to consume. This can be achieved by limiting the
number of go-routines available to execute our futures. This allows us to do
fancy things like creating multiple contexts for different parts of our application
and giving a way to define priorities by allocating more or less resources to
any particular scheduler.


So, back to the scheduler.  In reality a scheduler doesn't have to be anything
fancy. It simply needs to be a fixed number of go-routines to feed work to.

First let's define the basic interface we want our scheduler to have:

{% highlight go %}
type Scheduler interface {
  Run(func()) error
  Start() error
  Stop() error
}
{% endhighlight %}

Fairly simple, we can `Start()` and `Stop()` the scheduler which allows for
any setup or tear down of things like worker pools, channels, etc. The main
function however is `Run` which you'll notice only takes a `func()`. This `func`
does not take any parameters or return any values. This is very similar to calling
`go myFunc()` with the difference being that we've moved control over execution
of that func into the user-space.

### The Promise, the Future

__TL;DR__
TODO: write this part

Skip ahead to [next-section](#todo)

__Long Version__

With the scheduler we can now run concurrent computations within a bounded context. But
honestly this is not a huge improvement over:

{% highlight go %}
go lookNoSchedulers()
{% endhighlight %}

### Composability

_Sure you have a basic future, but you promised it could compose. What is this crap?
Think of the children!_

Fair point fellow human! Futures are not quite _the future_ if they cannot be composed.


### Wait! No More, Please!!

Oh of course! Can't have a good future implementation without the ability to cancel
chains built up using all that fancy composability.

  [github_genny]: https://github.com/cheekybits/genny
  [github_bastard_go_future]: https://github.com/JohnMurray/bastard-go/tree/master/future
  [john_io_future]: /log/2017/06/22/The-Futures-Abstraction.html
