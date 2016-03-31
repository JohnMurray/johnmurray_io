---
title: "Typed PATCH"
date:  2015-11-29 12:00:00:00
---

When building web services we need to define a contract of how the service
will operate and how the client should communicate with the service. One important
piece to this is the data that the service returns (usually on read operations)
and the data the service expects to receive (usually on write operations). One
really fantastic way to do this, especially when working in a language like Scala,
is to use types.

If I were designing a simple service to manage contacts, I might define my type
to look like:

{% highlight scala linenos %}
case class User(id: Long,
                name:         String,
                birthday:     Date,
                email:        Email,
                address:      Option[Address],
                createdOn:    Date,
                lastModified: Date)
{% endhighlight %}

This type accurately represents what I believe a contact, in the context of my
API, is defined as. All pieces except `address` are required 
and I also expect a few meta-data fields to exist such as `id`, 
`createdOn` and `lastModified`. This type works great when defining objects
in my system, but it starts to break down as a definition for a contract with a
consumer of my web-service. 

While this works decently well for read operations, where the full object
is returned, what does this look like for a create (`POST`) operation? To start I
no longer need any of what I'll call _"system provided"_ fields such as `id`, 
`createdOn` and `lastModified`. Some of you might be saying one of two things right
about now:

0. Default the fields to `null`
0. Make fields that aren't required an `Option`

I'm going to stop you right now. The purpose of this type is _supposed_ to be a way
to expose a contract to the user. Making fields that will _always_ exist on reads
an `Option` is really just a lie and not very useful for defining a complete contract.
To truly use types as our contract here, we need to define a create-specific type.
In our case, it might look like:

{% highlight scala linenos %}
case class UserCreate(name:     String,
                      birthday: Date,
                      email:    Email,
                      address:  Option[Address])
{% endhighlight %}

This gets us where we want to be at the price of having to create and maintain another
type in our application. 

Now it's time to think about how we would support operations such as PATCH which
are based around the idea of partial edits. Since, by the nature of partial edits,
everything is optional you can see that we can't use the same model that we used
for create. Also, since we will need to know the difference between null and absent,
we'll need to use a `TriState` value to represent any types that are currently 
nullable (or non-required by our default model).

{% highlight scala linenos %}
case class UserCreate(id:       Long,
                      name:     Option[String],
                      birthday: Option[Date],
                      email:    Option[Email],
                      address:  TriState[Address])
{% endhighlight %}

In the above model, we assume `Option` to be a matter of presence (not nullability) and
`TriState` to represent both presence and nullability.

Ta-da! We now have models that represent create, read, and partial edit. With this, we can
now work on optimizing our workflow. I think the proper step is to define an
abstract language that can define our service contract and allow our tooling to
generate our corresponding models for us. As a matter of fact, this is what we do
in Fireglass (an internal web-service framework) used at my current employment.

However, this framework is not (yet, maybe someday) open source. After some quick
looking around, I came across an older project that aimed to solve the problem via
macros. While I don't necessarily agree with the approach, it is a solution that is
available today.

[https://github.com/pathikrit/metarest](https://github.com/pathikrit/metarest)
