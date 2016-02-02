---
layout: post
title: "Web Service Data Models - Null"
date:  2015-05-04 12:00:00:00
---

> This relates to my other post "[Typed Actions In Play][1]". You may want to
> skim it to understand my aim in all this madness.

{% comment %}
This is in part a thought and in part a question. That being said, plese follow
post questions or comments on the [HN article][2] or the [reddit post][3].
{% endcomment %}

I'm on quest. I am attempting to create some abstractions that allow me to work
solely with well-typed models for the purpose of developing web services. I am primarily
working in JSON which means I just need to come up with a sound data-model for the
JSON that I expect to send/receive to/from the web-service clients. Sounds like a
fairly easy task, yes? Well, sadly it is not.

### Living with Null

Null values in JSON are a very interesting thing to represent in Scala. While Scala
does have the concept of `null`, it seems primarily as a way to survive interop with
Java, where using `null` is very common. However the conventional wisdom in the Scala
community is to replace `null` with `Option[T]` for some type `T` that is `null`'able.
`T` can then be represented as `Some[T]` or `None`. This makes a lot of sense, but it
fails to meet the requirements for JSON in the context of web services, and we'll see
why.

Let's assume that we're going to build a service to manage users. The JSON to represent
a user may look like this

{% highlight json linenos %}
{
  "name": "John Murray",
  "email": "my-email@gmail.com",
  "userName": "johnmurray_io"
}
{% endhighlight %}

Let's assert that the `userName` can be, in the JSON, either a string value or a `null`
value. Let's further assert that if the user does not provide this in the `POST` JSON
that it defaults to a `null` value.

For editing the object, let's assume that we accept partial edits over `PUT` and/or
`PATCH` (depending on which philosophy you subscribe to). This means that I do not 
have to supply the full JSON object, only the fields that I wish to edit. This is a 
very common practice in web services.

If I were only looking at the requirements for object creation, then I might define my
model like so

{% highlight scala linenos %}
case class User(name: String, email: String, userName: Option[String])
{% endhighlight %}

and the previous data would translate into

{% highlight scala linenos %}
User("John Murray", "my-email@gmail.com", Some("johnmurray_io"))
{% endhighlight %}

However, this model does not meet all of our requirements, only those for object creation.
Specifically what happens when I send in the following, partial update

{% highlight json linenos %}
{
  "name": "John M. Murray",
  "email": "my-other-email@gmail.com"
}
{% endhighlight %}

This translates into our model as being

{% highlight scala linenos %}
User("John M. Murray", "my-other-email@gmail.com", None)
{% endhighlight %}

You can easily see where the breakdown is. Because we do not have a value for the `userName`
it has no other choice than to be `None`. We are conflating the absence of a value with
the value being `null`. In the case that the value is absent on an edit operation, the user
does not _intend_ to edit the field. This means that we cannot reliably set the `userName`
field to an empty value, _ever_. To solve this we can introduce the `TriState[T]` type.

### Introducing the TriState[T]

As we have seen, we are in need of a type that can represent more than the two states
provided by `Option[T]`. To handle this, we're going to introduce a new type called
`TriState[T]` whose name we're borrowing from the world of electrical engineering. See
this article on [three-state-logic][4] for more details.

{% highlight scala linenos %}
trait TriState[T]
object TriState {
  case class Present[T](value: T) extends TriState[T]
  case class Absent extends TriState[Nothing]
  case class Null extends TriState[Nothing]
}
{% endhighlight %}

If we now replace the type of `userName` of `Option[T]` with `TriState[T]`, we can properly
represent the edit JSON in our model as:

{% highlight scala linenos %}
User("John M. Murray", "my-other-email@gmail.com", TriState.Absent)
{% endhighlight %}

From this, we know not to edit the field, since it is absent. Additionally if I were to
provide a null value on edit, we would know to set the `userName` to  `null`/empty within
our persistent storage solution. From this we can see that `Option`, for web services, is
better replaced with a `TriState`.





  [1]: {% post_url 2015-04-28-Play-Typed-Action %}
  [2]: #hn-article
  [3]: #redis-post
  [4]: http://en.wikipedia.org/wiki/Three-state_logic
