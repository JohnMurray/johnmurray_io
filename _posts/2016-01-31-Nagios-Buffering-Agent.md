---
title: "Instantly Better Monitoring"
date:  2016-01-31 12:00:00:00
---

Monitoring and alerting can be a very difficult thing to get right, and many of us
don't. I've been wondering how I can improve systems at my current work when I came
up with a simple way to get some minor improvements in our application alerting that
I thought might be meaningful to share.

# Context

At my current place of employment we make use of Nagios to perform checks and manage
alerts, a very common setup for many companies. However we have thousands of machines,
hundreds of applications, and a few hundred engineers all of which, for us, imply at
least two things:

+ Applications have moved heavily toward passive checks to reduce the amount of
  Nagios infrastructure require to keep up with active checks
+ Each application and/or team handles alerting in a different way, most resulting
  in noisy applications that generate many false alarms

With those conditions, being on pager has the potential to be a nightmare. A week or
two of no sleep will get you thinking about how you can reduce pager noise, and quickly.
In general most of our pain was around

0. Transient pages - alerts once and then goes green
0. Passive checks that do not clear (only alert on error)
0. Unneeded / duplicate checks. Flooding Nagios with errors when something bad happens or
   flooding Nagios with OK checks.


The general thinking went something like this:

> Well, I could just improve existing patterns around alerting. However, that's 15+ applications
> to mess with. __Nope, not fast.__
>
> Hrm... I could switch to using metrics-based alerting. There _is_ some work happening there
> within my company. __Nope, still not fast.__
>
> I wonder if there is a way to implement some best-practice patterns _outside_ of the
> application that is applicable to a variety of app types? __Yes, this sounds faster.__


# Solution

Going with the idea of "implementing some alerting best practices _oustide_ of the application",
I came up with [NBAd][github] (Nagios Buffering Agent <sub style="font-size:12px;">daemon</sub>).
NBAd runs alongside your application on the same machine and impersonates the Nagios NSCA
interface. Under the covers the application will:

+ Buffer incoming messages and keep a cache of last-seen messages, flushing to nagios
  on some interval
+ Proxy messages that represent a change in state from the last-seen messages (if still
  within the cache window)
+ Automatically clear error conditions after the message expires from the cache (receiving
  constant alerts will keep this value from clearing)

Because the application mimics the NSCA interface, integrating this with your application simply
means pointing your NSCA configs to use `localhost:5667` as the remote server. This effectively
makes NBAd a drop-in solution that doesn't require code changes to utilize. Now I can slightly
improve alerting across all my applications with a simple update to the puppet recipes (to
install NBAd) and an application config change.

For more information on the project, see the `readme.md` file on GitHub at
[https://github.com/JohnMurray/nbad][github].




  [github]: https://github.com/JohnMurray/nbad.git
