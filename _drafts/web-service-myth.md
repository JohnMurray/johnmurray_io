---
layout: post
title: "Moving to MicroServices - Duh"
---


<!--
OHHHH, fun idea.

Start with some simple application like ToDo list in Scalatra or something super simple with
the bare minimum config to make it work. Then go CRAZY about productionalizing it (being super
anal about every configuration and why it's important) to show how hard it can be to build
web-services.

The article should be all about how "easy" it is to build web-services and have a very sarcastic
tone about it. The title should not give away the fact that it is an ironic article.

- authentication
- rate-limiting
- nginx in front
- monitoring (nagios / NR / etc)
- metrics
- traceability (root cause analysis)
- transaction logging
- puppet recipes / docker
- LB / GSLB / redundancy & failover
- ACL & permission'ing
- Search
    - populating via trans-log
    - proxied to back-end search service through built-in magic /service/search?q=...
- talking to other services
    - caching
    - circuit-breakers and timeouts
- testing
    - CI servers / builds
    - mocking (service integration)

Ideas

    You need to make a "user memories" service. It extends user-information and also includes some
    things like "mood_id" (mood service), with_friend_id (friend service) for tagging the friend that
    was in the memory, name, description, and other usual data-fields (created/updated-on, etc).
        - moods is like a small lookup service
        - friend service is a larger dynamic service (can't cache)

-->

One of the fantastic advantages of working in micro-services is that they allow you to be
über agile not get bogged down with other people's changes and cruft. Also, we all know that
building web-services is like the simplest thing in the world. I mean, there are a bajillion
blog articles that show you how to go from 0 code to a working service in less than 10 minutes.
Extrapolating that out, I could build like 100 micro-services a day. Basically micro-services
are the way of the future for web-services, you'd be silly not to use them.

## Milton

Say hello to Milton. Milton is a all-star shadow ninja shogun wizard coder at Kao Hon (かお ほん), a Japanese
social networking site of completely original naming and idea. Milton works with a monolithic PHP application
on a daily basis but knows the _real_ secret sauce is in micro-services. Milton has convinced his manager
that micro-services are the one true way.

## Milton's Manager

Milton's manager, Bill, listens to Milton talk about micro-services all day. He really doesn't get it but
just says things like, "yeah sure" and agrees with Milton to get him to shut up. Milton's manager just cares
about getting shit done and showing results so he can claim their successes as his own.

## User Memories

Higher-ups as KaoHon have decided they want a new feature called "User Memories". People write some story
of a memory they have and tag one friend in the memory. They can also attach a mood to the memory and a
date of when it happened. The feature request is given to Bill and is expected to be delivered in 2 weeks.

## Monday

> __Bill__ - We need a new service for a new feature, "User Memories". Here is the spec.

> __Milton__ - [reads spec] \\
> __Milton__ - You know, this would be a great service to do as a "micro-service"

> __Bill__ - Huh? Oh, yeah. Sure. Can you have it to me in two Monday's from now? I need to present it then.

> __Milton__ - Pfft, I'll have it to you by this afternoon!

> __Bill__ - Wow! These mini services of yours are quite impressive.

> __Milton__ - Micro

> __Bill__ - [walks away without acknowledging]
