---
title: Inspecting JSON From The Command Line
---

Sometimes you need to inspect some heterogeneous JSON documents. I didn't see any good tools
out there that were better than me writing some custom shell scripts each time I wanted to inspect
or extract specific values. So... I made a little util called `json-inspect` that will do at
least two things that I needed. The first is to create a histogram from JSON values given a search
expression that allows us to search nested JSON documents. An example

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

And if instead of creating charts based on values we instead wanted to extract those values, we can do that
as well. An example

{% highlight bash %}
$ cat test.json | json-inspect ext "[].*.user.demographic.regions.[].*"
Louisville,Kentucky,US,Highland Heights,Kentucky,US,Wales,UK

$ cat test.json | json-inspect ext -d '|' "[].*.user.demographic.regions.[].*"
Louisville|Kentucky|US|Highland Heights|Kentucky|US|Wales|UK
{% endhighlight %}

This is up on my GitHub under the [json-inspect][1] project where you can find more information and usage information. 
I may contribute more to it later on if I find need or more functionality. If you have some cool inspection tools
you want to add, open a PR.


  [1]: https://github.com/JohnMurray/json-inspect
