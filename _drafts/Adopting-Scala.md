---
title: "Adopting Scala Successfully"
---

<!--
summary: organization thinking about adopting scala, some tips to make it Successfully

+ have 1 or 2 in-house "experts"
+ setup a forum for people to come and ask questions
+ define a fairly rigid tech stack (talk about scalaz here)
+ coding standards (automation tools / style guides)

-->


Adopting a new language into your technology stack is commonplace among larger companies
and startups alike. However, common or not, it is a decision that should not be taken
lightly. These are some opinions of what I think should be done to ensure a successful adoption
of Scala within your organization based on my personal experience bringing Scala to two
different environments.

## Measuring Success

Before getting into how I think you can "successfully" adopt Scala, we need to define the
criteria for success. I'll try to be brief

+ __Use__ - you are using Scala on production applications
+ __Velocity__ - product velocity is not lower due to new language adoption (in the medium term)
+ __Happiness__ - developers are generally happy with the choice in language adoption

<!-- TODO this list is too short, think of more things -->

## Do These Things

### #0. Have Good Reasons Why

I'll call this step #0, because it the most common-sense step and ideally it wouldn't even
deserve a place on this list. If you don't have good reasons to bring in a new language (or
any new technology for that matter), then you will likely fail to do so.

### #1. Have One or Two Scala "Experts" Already

If you do not already have some engineers who are knowledgeable about Scala, then you should
seriously consider moving forward. A programming language is much different than a piece of
application technology like Redis or Elastic Search (just to throw out some examples). Those
things may be complex, but can still be learned in depth in a reasonable amount of time
without requiring in-house experts.

On a new project that is using Scala, the experts can teach by helping
to write the code as well as performing code-reviews on developers are who are not as familiar
with the language. Reading the code of, and being code-reviewed by, the "experts" are great ways to
learn as a green Scala developer. This is not only a great way to teach, but necessary for
managing the cost of adoption by reducing the overall impact to team velocity.

### #2. Setup a Forum for Asking questions

Learning can be both an individual and group effort. As you introduce Scala to your organization
and as developers start to learn the language, people are going to have questions. You need to be
very clear that they have a safe place to come and ask questions without feeling silly. I find a
great way to do this is to provide a chat-room purely dedicated to answering Scala questions. The
"experts" from step #1 should also be monitoring this room for questions.

It also helps, if possible, to setup an "office hours" with the Scala experts. This is usually
an in-person forum that happens on a regular interval for some period of time (e.g. Every Tuesday
from 3 to 4pm). The in-person style of this is more suited for explaining larger concepts that
aren't easily answered in a chat-room. It also offers another venue for people that are not as
comfortable in a chat-room as they are in person.

### #3. Define Strict Domains of Usage

<!-- mandatory when doing X, don't make optional -->

### #4. Automated Conformity

<!-- style checking, formatting, etc. -->

### #5. Select Standard Libraries


## Don't Do These Things
<!-- TODO not sure if I want to do this section or not, but could be interesting if I have
          enough to say -->
