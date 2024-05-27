---
layout:  post
title:   "Typed Actions in Play"
date:    2015-04-28 12:00:00:00
archive: true
---

This is just something I was playing around with when discussing how to build
proper tooling for our teams at work. Play has the idea of an `Action` which
is basically a function that takes a `Request` object and returns a `Result`
object. Each of those can be parameterized for the content type being transmitted.

However, when you're working in an API, you typically work with some exchange format
(e.g. JSON) and then serialize and de-serialize to/from your internal data model. If
you are using Scala, then possibly some case classes. Rather than having to worry
about the exchange format, developers should really just worry about these data-models
when writing their code.

So, just the result of me playing with the idea for a few minutes:

{% highlight scala linenos %}
object TypedAction {
  def TypedAction[A,B](f: A => B)(implicit reader: Reads[A], writer: Writes[B]) : Action[String] =
    Action.async(BodyParsers.parse.tolerantText) { request =>
      val json = Json.parse(request.body)
      Future.successful {
        val badRequest: Result = Results.BadRequest("Could not parse input")
        json.asOpt[A](reader).map(f).map(Json.toJson(_)(writer)).map(_.toString()).map(Results.Ok(_)).getOrElse(badRequest)
      } : Future[Result]
    }

  def TypedAction[B](f: () => B)(implicit writer: Writes[B]): Action[String] =
    Action.async(BodyParsers.parse.tolerantText) { request =>
      Future.successful {
        Results.Ok(Json.toJson(f())(writer).toString)
      }
    }
}
{% endhighlight %}

And then using the model

{% highlight scala linenos %}
case class UserModel(id: Int, name: String)

object UserModel {
  implicit val reads = Json.reads[UserModel]
  implicit val writes = Json.writes[UserModel]
}
{% endhighlight %}

We can create a controller that looks like

{% highlight scala linenos %}
object UserController extends Controller {

  var userStore = Map(
    1 -> UserModel(1, "Joe Schmoe"),
    2 -> UserModel(2, "Susy Jane"),
    3 -> UserModel(3, "Jenny Jackson")
  )

  def getUser(id: Int) = TypedAction[UserModel] { () =>
    userStore(id)
  }

  def storeUser = TypedAction[UserModel, UserModel] { userIn =>
    val nextKey = userStore.keys.max + 1
    userStore += nextKey -> userIn
    userIn.copy(id = nextKey)
  }

}
{% endhighlight %}


We could also create different input and output models within the same
controller method. In addition, if you really wanted to do something like
this you would need to handle errors much better, both from the user code
and from the parsing code. I'm also not really doing anything with the
`Action.async` portion above, so that could be improved as well.

But yeah, just some (light) food for thought.
