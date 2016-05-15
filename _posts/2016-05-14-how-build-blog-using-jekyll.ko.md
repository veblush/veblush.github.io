---
layout: post
title: "Jekyll 로 어떻게 블로그를 만들었나"
date: 2016-05-14
categories: blog
lang: ko
---

지난 며칠동안 Jekyll 로 블로그를 만들었다. 길어야 이틀이면 만들 수 있을 줄 알았는데
몇몇 난관에 부딪혀 예상보다 오래걸렸다. 뭐 그래도 완성!

## 필요 조건

- 심플한 UI 를 가질 것
- 간결한 코드, 수식 입력이 가능할 것
- 영어, 한국어를 동시에 지원할 것

## 작업

##### # Github 저장소 만들기

[Github Pages](https://pages.github.com/) 서비스를 사용하기 위해 개인 github 저장소
[veblush.github.io](https://github.com/veblush/veblush.github.io) 를 만들었다.
Github 이 Jekyll 을 지원해 페이지 소스만 올리면 자동으로 사이트를 빌드해주는 편리한 기능도
지원하고 있으나 이 블로그의 경우 github 이 지원하지 않는 Jekyll 플러그인을 사용하기로
결정해 빌드는 수동으로 하기로 했다. 

##### # Jekyll 3 설치

[Jekyll](https://jekyllrb.com/) 3.1.3 을 설치했다.
Ruby 의 gem 툴을 사용해 간단히 설치할 수 있다.

```
> gem install jekyll
```

##### # 테마 선정

Theme 을 만들기엔 능력도 부족하고 시간도 없어 이미 있는 테마를 골라 사용하기로 했다.
다른 여러 테마를 보고 고르는게 생각보다 시간을 많이 써야하고 고민스러운 일이다.
테마 사이트에서 여러 테마를 보면서 갈피를 못잡다가 정작 눈에 띈 것은 우연히 방문한
[nithinbekal](http://nithinbekal.com) 블로그의 테마였다.
깔끔하고 간결한 것이 처음 목적으로 했던 심플한 UI 를 만드는데 적합해 보였다.
이 테마를 기본으로 취향에 맞춰 layout 과 css 를 살짝 수정했다.

##### # Polyglot 플러그인 적용

Jekyll 은 다국어 지원을 기본적으로 제공하고 있지 않다. 이를 지원하기 위해
여러가지 방법이 있는데 [Polyglot](http://untra.github.io/polyglot/) 을 사용하기로 했다.
사용하기 쉬워보이는 첫인상 때문이었다. 하지만 이해하고 적용하는데 시간을 많이 소모했는데
결론적으로 플러그인이 윈도우 환경에서 잘 동작하지 않는 버그 때문이었다.
Jekyll 에 익숙하지 않으니 버그가 있는 것인지 내가 뭘 잘못 사용 하는 것인지 구분이 되지 않아
문제를 파악하는데 시간이 좀 걸렸었다.
해당 버그의 [수정](https://github.com/untra/polyglot/commit/3280a2d84da1a36929fb5615426349dc6cccf4c3)
PR 이 받아들여져 이제는 문제 없이 사용할 수 있다.

##### # Asset Path 플러그인 적용

글마다 그림 등 데이터를 별도의 리소스 디렉토리가 있는 것이 관리하기 좋을 것 같아
이를 위한 플러그인 [Jekyll Asset Path](https://github.com/samrayner/jekyll-asset-path-plugin)
를 설치했다.
Polyglot 룰에 맞추고 애셋 디렉토리명을 글의 파일 이름과 맞추는 수정사항을 추가로 구현했다.

##### # 기존 블로그 데이터 임포트

기존 블로그에 있는 글들을 임포트해왔다. 기존의 블로그는 HTML 형태로 받아올 수 있었는데
이를 [Pandadoc](https://www.pandadoc.com/) 을 사용해 일차적으로 markdown 포맷으로 변환하고
이상하게 변환된  마크업들을 처리했다. 여기에 더해 글에 포함된 이미지 링크를 Asset 경로로 변경하고
수식을 kramdown [문법](http://kramdown.gettalong.org/math_engine/mathjax.html)에 맞춰 정리했다.
다행히 (!) 기존에 작성한 글이 많지 않아 이 과정이 오래걸리지는 않았다.

##### # Publish 스크립트 만들기

Github 저장소에 브랜치 2개를 만들었다.

- site 브랜치: 블로그 원본이 담긴 working branch.
- master 브랜치: site 브랜치의 내용을 jenkyll 빌드하면 나오는 블로그 결과 페이지.

Publish 스크립트는 site 브랜치에서 jekyll 을 통해 build 를 하면 그 결과를
master 브랜치에 업데이트 하는 식으로 동작한다. 다른 사람들이 만들어 놓은 스크립트가
잘 동작하지 않아 간단한 [배치 파일](https://github.com/veblush/veblush.github.io/blob/site/publish.cmd)을
통해 적당히 자동화 하였다.
