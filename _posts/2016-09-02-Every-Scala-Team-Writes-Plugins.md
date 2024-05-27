---
layout:  post
title:   Your Team Should Write SBT Plugins
archive: true
---

__Every Scala development team should be writing their own SBT plugins. If you're not then
you're doing it wrong__.

This is an <s>assertion</s> assumption I am making based on what I've seen so far in my limited
experience working on/with various teams and their Scala applications.

## Standards

Organizations (not just large ones) typically have standards. Standards for various things including

* code style
* application packaging
* release process
* deployment

The list goes on. The general idea however is that if you are building a new application, it should
conform to the standards that (ideally) all the other applications in the organization follow.

Now if we're talking about Scala projects, we have some wonderful tools for defining all of these
standards. Specifically I'm talking about SBT. It is the Scala developer's Swiss army knife. I know
that if I start a Scala project today I can use `sbt-release` for defining my release process
(all the steps / actions I take to release my code) which includes essentials standards items such
as a versioning scheme. I can also use `sbt-native-packager` to build `deb` or `rpm` packages
for Linux or docker images for [_insert cloud platform here_]. I may also set up my applications
with a few useful utilities depending on what I'm writing, such as

* `scalastyle` (and/or `sbt-checkstyle` if I have some Java code as well)
* `sbt-reloader` (for easy running of my app locally)
* `sbt-doge` (if I'm managing multiple release versions of a lib, or developing an SBT plugin as part
of a suite of libraries)
* `sbt-dependency-graph-sugar` (for viewing pretty dep-graphs)

The list goes on. And a lot of it depends on the style or particular flavor of Scala development
at each organization.

## Maintaining Consistency

So you got your recipe of Scala programming goodness all bundled up in your `build.sbt`, that's
great! But wait, how do you make sure that other projects use the same data. Well you could just
copy it around at first if we're talking about a handful of applications. Beyond that maybe we
make a general template that people clone from to start their projects. But wait, what if the
organization decides it wants to add a new step to that sweet release process you wrote using
`sbt-release`? Well, now you need to hop from project to project, updating each `build.sbt`. And
you can't just copy and paste anymore because you might override some application-specific settings
that have built up over time.

There is actually a very simple solution to this problem, organizational SBT plugins. These are plugins that
are written for the express purpose of wrapping up all these organizational standards into simple SBT
plugins. You have an awesome release process? Great! Wrap that up into an SBT `AutoPlugin` that uses
the `sbt-release` plugin internally. All that is required for an application to conform to the
standard release process is to add a simple addition to their project definition.

{% highlight scala %}
project.enablePlugins(OrganizationReleasePlugin)
{% endhighlight %}

## Using Archetypes

Once you start wrapping this functionality up into your own SBT plugin, you may notice that not _all_
of the applications in your organization fit the same mold. For that we have archetypes. An archetype
is a "top-level" `AutoPlugin` for a particular application type.  Archetypes are very much like meta-packages
in OS package management systems; it is a collection of `AutoPlugin`s tailored for that specific use case.

For example, a `ScalaWebService` archetype may contain specific plugins and settings for a PlayFramework
application where as a `AkkaKernel` archetype will have a slightly different set of plugins and settings.
Additionally if your organization supports both Java and Scala, you can make those separate archetypes
as well to make the provided plugins more tailored toward specific application needs while still maintaining
a set of standards for each supported archetype.
