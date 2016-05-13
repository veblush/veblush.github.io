---
layout: post
title: "Why I move to Jekyll for my blog"
date: 2016-05-13
categories: blog
lang: en
---

I used common blog service in creating my blog at 2012.
Blog service was good to write blog right after a few clicks even
it had some drawbacks.
Theseday I have some spare time for this and decide to change it.
 
## Drawbacks of blog service

##### # Not easy to embed code and math expression

Embeding code is not easy. My blog has lots of code blocks to be embeded.
Whenever code need to be inserted, I switch blog to HTML mode and insert
a few HTML code for that and switch it back to writing mode,
which is quite bothersome.

Embeding math expression is not easy, too. There is a nice web service to
provide the way to convert LaTeX math expression to an image dynamically.
I used it happily but it requires some manual steps. Also my blog depends on
external service that could be down for maintenance or disappear forever.

##### # Need to store original data of diagram separately

GraphViz and Excel are used for authoring graph and chart which are converted
to images and inserted to blog. For futhur updates, source files
should be stored but because blog service does not provide storage, I backup
these files to the separate place, which is tiresome and easy to forget.

## Why I choose Jekyll

##### # Easy to embed code and math expression

If you are accustomed to using markdown, it is really hard to imagine a better
way than using markdown to insert a code block.
Jekyll uses [kramdown](http://kramdown.gettalong.org/) as a default
markdown engine which is goot at dealing with code and math expression.

Code block with syntax highlighting is rendered like:

```javascript
function fancyAlert(arg) {
  if(arg) {
    $.facebox({div:'#foo'})
  }
}
```

Math expression by LaTeX format is rendered like:

$$
\frac{n!}{k!(n-k)!} = {n \choose k}
$$

##### # Hosting on Github

Github provides pages service for hosting a static web site.
It's free and good to keep original source files of diagram and chart along with web site.

##### # Simple architecture and highly customizable

Jekyll is a simple tool to transform plain texts to htmls.
It's easy to understand and can be customized as you want.
With greate customization comes great labor.
In my case, multi langauge plugin [polyglot](https://untra.github.io/polyglot/) is used to support
english and korean at the same time.

