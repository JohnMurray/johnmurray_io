---
layout:  post
title:   Inspecting JSON From The Command Line
archive: true
---

Sometimes you need to inspect some heterogeneous JSON documents. When it comes to working with JSON
there are a lot of great libraries out there. However, there aren't many tools out there that
allow me to work with JSON in the shell without resorting to writing small custom bits of Python
or Ruby each time. And even this doesn't always get me as far as I'd like it to without writing
larger blocks of Ruby/Python code to dig through large / complex JSON documents.

Given the title of this post, you can see where this is heading. I have created a simple command
line utility as a gathering place of functionality for inspecting JSON documents. I'll show off
some features of the tool.

If you want to follow-along with the examples I'm showing, feel free to install the tool from
[PyPi][json_inspect_pypi] via

{% highlight bash %}
pip install json-inspect
{% endhighlight %}

Let's first make a file `test.json` to contain some fake JSON data to play with

{% highlight json %}
[
 {
   "facebook": {
     "user": {
       "demographic": {
         "regions": [ {"name": "US"}, {"name": "Kentucky"}, {"name": "Louisville"} ]
       }
     }
   },
   "google": {
     "user": {
       "demographic": {
         "regions": [ {"name": "US"}, {"name": "Kentucky"}, {"name": "Highland Heights"} ]
       }
     }
   }
 },
 {
   "twitter": {
     "user": {
       "demographic": {
         "regions": [ {"name": "UK"}, {"name": "Wales"} ]
       }
     }
   }
 }
]
{% endhighlight %}

## Frequency

If you are working with JSON data that you do not control (think data integrations)
then you sometimes need to compare their specification of the data with the data
you are actually receiving. For this we can create a histogram of values based on a
search expression.

{% highlight bash %}
$ cat test.json | json-inspect histo '[].*.user.demographic.regions.[].name'

[].*.user.demographic.regions.[].name:
Highland Heig   | #########################                          | (1)
US              | ################################################## | (2)
Louisville      | #########################                          | (1)
Kentucky        | ################################################## | (2)
UK              | #########################                          | (1)
Wales           | #########################                          | (1)
{% endhighlight %}

Maybe I'm biased, but this is great! I was able to inspect this JSON document with
minimal command-line-foo.

## Search Paths / Expressions

The heart of the previous example is the search expression. It currently consists of
three parts (working on a recursive `**` operator) which are

+ `[]` - Represents an array (containing objects)
+ `*` - Represents all fields within an array
+ `TOKEN` - This is a field name within an object

The `[]` and `*` tokens will result in all values being processed by the next token
in the path. The path itself is delimited by `.`, so this means that field-names
with `.` in them are not supported.

## Values

And if instead of creating charts based on values we instead wanted to extract
those values, we can do that as well. An example

{% highlight bash %}
$ cat test.json | json-inspect ext "[].*.user.demographic.regions.[].*"
Louisville,Kentucky,US,Highland Heights,Kentucky,US,Wales,UK
{% endhighlight %}

We can also control the delimiter to make piping values into other command-line tools
easier.

{% highlight bash %}
$ cat test.json | json-inspect ext -d '|' "[].*.user.demographic.regions.[].*"
Louisville|Kentucky|US|Highland Heights|Kentucky|US|Wales|UK
{% endhighlight %}

## Keys

So far we've seen inspection tools around the values within JSON, but what if we want to
see what keys are available within the JSON document? We can easily pull all keys of a JSON
document out with

{% highlight bash %}
$ cat test.json | json-inspect keys
facebook.user.demographic.regions.name
google.user.demographic.regions.name
twitter.user.demographic.regions.name
{% endhighlight %}

Additionally, we can provide some options which will filter out nulls, empty objects,
empty primitives, and empty arrays as `-n`, `-o`, `-p`, and `-e` respectively. We could
introduce some new fields to our `"facebook"` object to test.

{% highlight json %}
{
 "facebook": {
   "user": {
     "demographic": {
       "regions": [ {"name": "US"}, {"name": "Kentucky"}, {"name": "Louisville"} ]
     },
     "null": null,
     "empty_object": {},
     "empty_array": [],
     "empty_primitives": {
       "string": "",
       "int": 0,
       "float": 0.0
     }
   }
 }
}
{% endhighlight %}

Okay, so if you just ran the same command we used earlier, you would see all of these new
keys. But we can easily filter some or all of them out with some options. To get back to
our original set

{% highlight bash %}
$ cat test.json | json-inspect keys -nope
facebook.user.demographic.regions.name
google.user.demographic.regions.name
twitter.user.demographic.regions.name
{% endhighlight %}

## The Source

This is up on my GitHub under the [json-inspect][1] project where you can find more
information and documentation. I plan to contribute further to this project as I have
need, but if you have ideas for useful features and want to contribute, feel free to
open PRs.


  [1]: https://github.com/JohnMurray/json-inspect
  [json_inspect_pypi]: https://pypi.python.org/pypi/json-inspect
