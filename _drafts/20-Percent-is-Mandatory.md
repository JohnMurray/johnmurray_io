---
title: "20 Percent is Mandatory"
---

We're all familiar with Google's _20%_. The developers' dream of spending company time on personally
interesting projects. Every developer seems to desire this, but very few companies are truly offering
it. I'm gonna make a claim that 20% time is not a "nice to have" but a mandatory practice that all
companies should be following.

I would like to redefine 20% a bit for my purposes to means

> Twenty percent of employee time spent on projects outside of their current mandate that relate
> to company initiatives and goals, the technical platform's stability and performance, or engineering
> velocity.

Google's 20% may follow rules such as this as well (not familiar enough with their process), but the basic
point is that the work should be _related_ to the company in some way and not _entirely_ personal projects.

# The Normal Grind

So this sounds nice and all, but why should this be mandatory? Well, let me know if any of the following
scenarios sound familiar to you.

__Product Rules__

The company is hyper-focused on delivering product as fast as possible. You are either in startup-mode and
attempting to be lean or possibly an enterprise going after large business opportunities. Either way, product
teams dominate and all of the engineering resources are dedicated to developing features as fast as possible.
As products are pushed out, technical-debt increases at a rapid pace, slowly taking more and more of a toll
on engineering velocity.

__Retro-Active Infrastructure Development__

For a variety of reasons (possibly due to a "Product Rules" scenario), the infrastructure that powers your
company is ignored. It was built long ago and has "worked" up till now, so no resources have been allocated
to maintain it. However one or more core / critical components are starting to buckle under the stress of the
organization (or already have) and now we must make fixes or we're doomed. The company is now in emergency
mode that can be anywhere as severe as losing a client or going out of business if the issue cannot be fixed
in a timely manner.

__Wow That's Old__

All of your work is built on top of _some_ framework. That framework could either be something that was built
in-house or an open-source framework. Regardless, it's old and out-dated. Don't get me wrong, it still works and
functions as it should. However there is a lot of opportunities for productivity that are lost because the
framework has not been given the proper amount of attention in either continued development (in-house) or upgrading
to more recent versions (open-source). While this doesn't have an immediate impact on _current_ velocity, there
are certainly missed opportunities for productivity which means your competition might have a leg-up on you here.

__Internal Open Source__

At some point in the past a framework, library, or tool was developed. After it was created it was sent around
and the source was put up on some VCS server. The original writer doesn't really have time to maintain it so he
"internally open sources" the project. Even though the project is oft used, no one touches the code, even if
there are issues because they don't have time.

__The Wall__

Large companies often build software that is dependent upon other components / systems that are built by other
teams. When an issue is encountered it is simply thrown "over the wall", meaning _to the team that owns the
system the bug is filed against_. However both teams have already planned their quarters and don't really have
time to fix the issue. Months go by until eventually the team that filed the bug either lives with it or
escalates their product as being a "company priority"; re-prioritizing the owning team to fix the bug as part
of their _planned work_ for the quarter.

# All About the Debt

I hear what you're saying, "this is all just fancy ways of saying _'technical debt'_." Well, kind of, but there's
more to it than that, technical debt is just a side-effect. It's about your engineers not working collaboratively
or with shared goals. When engineers are expected to dedicate 100 percent of their time to company initiatives,
they don't like to go out of their way to collaborate with other teams for fear that it could impact their own
deadlines. You can see silos developing as engineers become hyper-focused (or _"laser-focused"_ if you prefer) and
engineers working without context of other projects outside of their teams.

# The Improved Flow

So all of this sounds bad, or typical depending on your perspective, and your wondering if 20% really fixes any
of this. Again the answer is, _kind of_. Simply introducing a 20% time and no structure may not get you the
results you desire. That's not to say that _some_ of the above can't be achieved without structure:

+ __Internal Open Source__ - Community managed projects are fret with small issues, feature requests, etc that are
                             easily solvable with small amounts of time. Additionally knowledge of the
                             framework/library/etc can be built over time, allowing developers to tackle larger
                             improvements down the road.
+ __The Wall__             - More time to track down root-causes to issues and possibly propose fixes to systems
                             not "owned" by the engineer's team.
+ _Other Small Stuff_      - It's easy for a single engineer to tackle small stuff on their own in relatively short
                             periods of time. Allowing your entire organization to follow the "boy scout rule" (leave
                             things nicer than you found them) can have a large impact over time.

<!-- TODO: make capitalization of "Guild" and "Working Groups" consistent (upper case please) -->

However, how do you handle the larger issues that exist? This takes coordination and planning. But how do you
bundle that in with 20% time? While there are likely many ways to approach this, I propose approaching it with
two strategies. Since I suck at naming I'll call these two strategies Guilds and Working Groups. Let's define
them

+ __Guild__         - Permanent group (members can change) with a specified subject-focus (e.g. metrics, performance,
                      analytics, etc).
+ __Working Group__ - Ephemeral group formed for solving a pre-determined problem. Group disbands once the problem
                      has been solved / addressed.

If both of these strategies are meant to address larger issues, what is the difference? Let's look at something like
metrics. Metrics is a problem with most tech organizations. Either we're doing it wrong or there is much more that
can be gained. The Guild strategy is useful here as it creates a long-lasting organization to solve both the
current problems with metrics but to foster a culture of good metrics and push for continual improvement going
forward. The problem is never really solved and there is always room for improvement.

Now, what about upgrading that web-framework you're using so you can support HTTP/2 and Web-Sockets? While this
may be a large task (lots of code to update) it has a very clear start and end. This is where the Working Group
strategy shines. A group can be formed with interested members who divvy up the work and make progress toward
a shared goal. A Working Group can take on small or large projects, as long as the end-goal is very clearly
defined.

There is also a relationship that exists between Guilds and Working Groups. While a Guild is focusing on the long-term,
it may still identify issues that would best be served by a Working Group. In this situation, the Guild can be
a facilitator to help organize (and possibly manage) Working Groups.

# 20% Sounds Like a Lot

20% is just what Google does (or claims to do), not some magic value that will solve all your woes. Pick some
percentage or allotment of time that allows your engineers to work in the __Improved Flow__.
