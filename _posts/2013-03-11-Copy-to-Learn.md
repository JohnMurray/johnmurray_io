---
layout:  post
title:   "Copy to Learn"
date:    2013-03-11 12:00:00
archive: true
---

While I have stated my opinion in the past that you should think twice before
creating another web framework, it can be a useful tool. In particular, if you
are familiar with a web framework in your language of choice, it may be a
good learning exercise to try and implement that framework in another
language. __Note__ however that you should likely not try to get people to use
your new framework if it is only for learning purposes. If you are seriously
considering creating a new web framework, please read my post [New Web
Frameworks][1].

## Background
I've recently (as of the time this post was written) taken a new position in
AdTech doing PHP for the purpose of web services. I really don't know too much
about PHP and it's been a while since I've last encountered real PHP code. So,
I figured that a little homework was in order.

I figured that the best way to learn would be to create a fun project in PHP
that could utilize many of PHP's newer features. For this, I wanted to create
a (very) simple clone of my favorite web-app framework, [Sinatra][2].

## Goals

Obviously the main goal is to better learn PHP's main language features, but
let's talk more about what the goal of the project will be:

+ Implement basic Sinatra/HTTP routing methods (GET, POST, PUT, DELETE)
+ Provide pre and post hooks
+ Implement parameratized routes in Sinatra fashion
+ Use lambdas to provide an _authentic_ Sinatra-experience
+ Use PHP 5.4 features (where possible/applicable)

## Result

The result is a framework called Pinatra (to make it even more obvious my
intent) that is available on my Github [here][3]. Let's see how well I did
at meeting the aforementioned goals:

### Basic Routing

This was relatively simple. To get started, I created a main class `Pinatra`
that I could use to register my routes with. I then created methods for each
HTTP verb I would be supporting (GET, POST, PUT, DELETE) that took a path (a
string) and a handler. The handler would then be called if the incoming
request could be matched against the route. The method for registering a GET
request looked generally like:

{% highlight php5 linenos %}
public static function get($match, $callback) {
  $app = Pinatra::instance();
  $app->register('get', $match, $callback);
}
{% endhighlight %}

As you can see, we are simply taking the route to match (the `$match`) and a
callback (a callable) and sending that on to the `register` function. So, to
look at the register function:

{% highlight php5 linenos %}
private function register($method, $match, $callback) {
  $match = $this->compute_regex($match);
  $this->routes[$method][$match] = $callback;
}
{% endhighlight %}

You can see here that we are extracting a regex out of the given match (we'll
look more at that later) and we are registering the route in a local hash based
on the HTTP verb (`$method`).

We can use this very simply now as:

{% highlight php5 linenos %}
Pinatra::get('/hi', function () {
  return 'hello world';
});
{% endhighlight %}

Very similar, we can register POST method like the following:

{% highlight php5 linenos %}
Pinatra::post('/name', function ($data) {
  return 'Hello ' . $data['name'];
});
{% endhighlight %}



### Pre/Post Hooks

Using the same functionality used to register the routes on a particular HTTP
verb, we can also register before and after hooks. When we create them in our
application, it is as simple as:

{% highlight php5 linenos %}
Pinatra::before('*', function () {
  header('AppVersion: 0.0.1');
});
{% endhighlight %}

{% highlight php5 linenos %}
Pinatra::after('*', function () {
  Logger::log_request('served yet another request');
});
{% endhighlight %}



### Parameratized Routes

This is a way of representing data in a given route that is extracted
automatically. For example, given the following route:

{% highlight text linenos %}
/authors/:author_id/books/:book_id
{% endhighlight %}

I should be able to extract the two values, `:author_id` and `:book_id`.
Earlier you saw a method for building up the regular expression. This is
what we'll use to create our route and the match-patterns will be used
to extract the route-data. The method for generating our regex from the
user-supplied route is seen below.

{% highlight php5 linenos %}
private $URIParser_PLACEHOLDER = '([^\/]+)';
private $URIParser_GLOB = '.*?';

/**
 * Private: Generate a PHP (Perl) regular expression given the
 *          Sinatra-style expression in the get/post/put/etc. functions.
 */
private function compute_regex($match) {
  // get the URI parts of the match-pattern given
  $parts = array_filter(explode('/', $match), function ($val) {
    return !empty($val);
  });

  // build our pattern-matching regex from given route
  $regex= '/^';

  foreach ($parts as $part) {
    if ($part[0] === ':') {
      $regex .= '\/' . $this->URIParser_PLACEHOLDER;
    }
    else if ($part[0] === '*'){
      $regex .= '\/' . $this->URIParser_GLOB;
    }
    else {
      $regex .= '\/' . $part;
    }
  }
  $regex .= '\/?$/';
  return $regex;
}
{% endhighlight %}

You can see how the match patterns could be used to extract data from
the URI. This can then be passed to the route-methods. An example of how
this would look is as such:

{% highlight php5 linenos %}
Pinatra::get('/hello/:name', function($name) {
  return $this->json([
    'key' => 'hello-route has been matched!',
    'name' => $name
  ]);
});
{% endhighlight %}

You'll also notice a JSON helper function (I'll leave that one for your own
exploration).


### Lambdas

You've already seen the use of lambdas (anonymous functions) in my examples
so far, so suffice it to say, I met that goal. One important thing to note is
that newer versions of PHP provide easy way to rebind anonymous methods making
it possible to use them here. Take a look at the method that actually matches
a request to a route and calls a lambda:

{% highlight php5 linenos %}
  /**
   * Method that is called when we actually want to process an incoming
   * request based on the method and uri provided. This method (expecting
   * to be given a URI and method) can also be used for re-routing requests
   * internally.
   */
public static function handle_request($method, $uri) {
  $app = Pinatra::instance();


  // before hook code (removed for brevity)

  // find and call route-handler
  $route_match = $app->find_route($app->routes, $method, $uri);
  if ($route_match !== null) {

    $request_body_data = $app->get_body_data($method);
    if ($request_body_data !== null) {
      array_unshift($route_match['arguments'], $request_body_data);
    }

    $route_res = call_user_func_array(
      $route_match['callback']->bindTo($app),
      $route_match['arguments']);
  }

  // after hook code (removed for brevity)

}
{% endhighlight %}

### PHP 5.4 Usage

Several features were used, but the main new 5.4'ish feature that got used
was traits. They were fun, but I probably used them wrong. Anyways, I'll leave it
up to you to check out my usage, however I will say that I mainly used them
as modules and not so much as re-usable traits.


## What Was Learned

While I already knew that a PHP script ran every time a new request was made,
I learned that PHP may not be the best language in which to implement a
Sinatra-like [DSL][4]. Simply put, we must register all of the routes on every
request. Since we cannot cache these results, we end up doing a lot of parsing
and string manipulation on every request. This means that as you add new routes,
you incur overhead on every new request, even if that route is never called.
This is unlike other languages in which the application starts up once and then
those computed routes (regex's) can be cached and re-used.

## Final Notes

Like I had mentioned previously, this project was to learn. That being said, there
is probably a lot of debug code and comments left in this project and I would not
recommend it for real-world use. So, if you do want to play around with it, you might
have to remove some `echo` and `var_dump` statements that might still be hanging
around in the code.




  [1]: {% post_url 2012-04-19-New-Web-Frameworks %}
  [2]: http://sinatrarb.com
  [3]: https://github.com/JohnMurray/pinatra
  [4]: http://en.wikipedia.org/wiki/Domain-specific_language
