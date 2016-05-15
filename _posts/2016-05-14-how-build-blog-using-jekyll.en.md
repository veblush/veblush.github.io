---
layout: post
title: "How I build my blog using Jekyll"
date: 2016-05-14
categories: blog
lang: en
---

Recently I has been building blog. It was expected to take
at most 2 days but more time spent because of some traps.
But anyway it's done!

## Requirements

- Simple UI
- Easy to insert code blocks and math expressions
- Supports both english and korean

## Works

##### # Create Github repository

Personal github repository 
[veblush.github.io](https://github.com/veblush/veblush.github.io) is created
for hosting blog by [Github Pages](https://pages.github.com/) service.
Github provides the neat way to build sites from Jekyll source pages automatically
but it cannot be used because using plugins is not allowed by github.
So manual build process have to be prepared.

##### # Install Jekyll 3

[Jekyll](https://jekyllrb.com/) 3.1.3 is installed.
With ruby gem utility, it is quite easy.

```
> gem install jekyll
```

##### # Theme

I don't have the ability to design web sites and don't have time to do it, either.
So I decided to use theme but choosing right theme among tons of themes is really
time-consuming and hard-to-pick work.
But accidently tidy blog [nithinbekal](http://nithinbekal.com) was found and
the theme of that was chosen to use. It looks simple and best fit to my requirement.
Based on this theme, layout and css has been modified slightly.

##### # Setup Polyglot plugin

Official i18n support is not provided by Jekyll. There are a few ways for supporting it.
[Polyglot](http://untra.github.io/polyglot/) was chosen for this blog
because it seemed simple to use and neat. 
However it took many hours to setup it because I was not familar with
the detail of Jekyll and there was a weird bug of polyglot active on windows.
Finally this bug is [fixed](https://github.com/untra/polyglot/commit/3280a2d84da1a36929fb5615426349dc6cccf4c3)
and it works well now.

##### # Setup Asset Path plugin

It seems better to allocate local storage for each post because some of post have
lots of images or diagrams generated with graphviz which are not shared by other posts.
[Jekyll Asset Path](https://github.com/samrayner/jekyll-asset-path-plugin) is installed for this.
It works well and is slightly modified to support Polyglot and my own directory naming rule.

##### # Import old blogs

All posts from previous blog can be imported as HTML format. These HTML articles are tranformed
to markdown with [Pandadoc](https://www.pandadoc.com/). Most of them are good but there are some
incorrect markdowns that should be corrected by hand.
Image links are changed to fit asset directory and math expressions are converted to
kramdown [form](http://kramdown.gettalong.org/math_engine/mathjax.html).
Fortunately it doens't take long because there are not many articles to be imported.

##### # Write publish script

Two branches are created on Github repository.

- site branch: Working branch for storing original source of blog.
- master branch: Output branch for storing the result of Jekyll from site branch.

[Publish script](https://github.com/veblush/veblush.github.io/blob/site/publish.cmd)
will run Jekyll at site branch and copy output to master branch to update blog.

