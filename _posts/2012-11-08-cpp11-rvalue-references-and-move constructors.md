---
layout: post
title: C++11 우측값 참조와 이동 생성자
date: 2012-11-08
categories:
  - cpp
lang: ko
---

C++11 과 함께 등장한 많은 기능들은 대부분 간단하거나 직관적인 기능이라 이해하기 쉽다.
그런데 몇몇 기능은 이해하기 까다로운데 그 중 제일을 뽑으라면 우측값 참조와 이동 생성자를 들겠다.
간단한 기능이 복잡한 문법과 이해를 요구하기 때문이다.

## 시작

15년전 C++ 를 처음 배웠을 때 (신경써서) 처음으로 만든 클래스는 문자열 클래스였다.
C 의 번거로운 문자열 제어 작업을 쉽게 해보고 싶기도 했고 복사 생성자,
연산자 오버로딩 등 C++ 의 기능을 충분히 사용해 볼 수 있었기 때문이었다.

다음과 같이 작성된 C 의 문자열 연결 작업은

```cpp
char* s = (char*)malloc(strlen(a) + strlen(b) + 1);
strcpy(s, a);
strcat(s, b);
```

C++ 의 문자열 클래스 String 를 사용하면 아래와 같이 산뜻하게 기술할 수 있다.

```cpp
String s = a + b;
```

이 String 클래스는 아래와 같이 문자열 길이와 버퍼를 가지는 형태로 구현되었다.

```cpp
class String {
  size_t len;
  char* buf;
public:
  String() : len(0), buf(nullptr) {}
  ~String() {
    delete [] buf;
  }
  String(const String& s) {               // 복사 생성자
    len = s.len;
    buf = len > 0 ? new char[len] : nullptr;
    memcpy(buf, o.buf, len * sizeof(char));
  }
  String operator = (const String& s) {   // 대입 연산자
    delete [] buf;
    len = s.len;
    buf = len > 0 ? new char[len] : nullptr;
    memcpy(buf, s.buf, len * sizeof(char));
  }
  //...
};
```

하지만 문자열 클래스를 만들면서 고양된 기분은 operator + 함수를 구현하면서 가라앉았는데
그 operator + 는 아래와 같이 구현되었다.

```cpp
String operator + (const String& a, const String& b) {
  String r;
  r.len = a.len + b.len;
  r.buf = new char[a.len + b.len];
  memcpy(r.buf, a.buf, a.len);
  memcpy(r.buf + a.len, b.buf, b.len);
  return s;
}
```

이 operator + 함수는 다음과 같이 사용된다.

```cpp
String x("head"), y("tail");
String s = x + y;
```

실행되는 코드를 구체적으로 살펴보면 다음과 같다.

```cpp
String x("head"), y("tail");
  String r;                       // operator + 함수의 지역 변수
  r.(len, buf) = run_operator +;  // 문자열 연결 실행
String s(r);                      // r 을 가지고 s 생성
  r.~String();                    // r 소멸
```

위의 r 은 operator + 안에 있는 결과 객체 r 이다.
계산이 완료되어 결과를 담고 있는 r 은 s 에게 넘겨지는데 이 때 변수의 복사생성자 혹은
대입연산자가 불리고 나서 r 은 바로 소멸된다. 그런데 String 클래스는 생성/소멸 때
힙 할당과 해제를 수행한다.
만약 클래스의 생성/소멸이 간단했다면 무시했겠지만 힙이라면 그냥 넘기기 어려운 일이다.
기대했던 군더더기 없는 operator + 실행은 아래 같았다.

```cpp
String x("head"), y("tail");
String s;
  s.(len, buf) = run_operator +;  // 문자열 연결 실행
```

함수의 리턴값으로 결과를 반환해야 한다면 이 문제를 피할 수 없었다.
리턴값을 사용할 수 없으면 연산자 오버로딩도 제대로 사용하기 어려우니 폼나는 C++ 형식을
사용하려면 불필요한 값 복사를 감당해야 했다.
그래서 성능이 중요한 클래스는 리턴값으로 결과를 반환하기 보다는 함수의 인자로 참조를 넘겨 결과를 돌려 방법을 사용했다.

```cpp
void Concat(const String& a, const String& b, String& r) {
  r.clear();
  r.len = a.len + b.len;
  r.buf = new char[a.len + b.len];
  memcpy(r.buf, a.buf, a.len);
  memcpy(r.buf + a.len, b.buf, b.len);
}
```

불필요한 값 복사와 그에 수반되는 객체 생성/소멸 비용는 C++ 의 아킬레스건이 되었고
이를 해결하려고 하는 시도가 있었다.

## 시도

프로그래머들은 객체 복사때 발생하는 깊은 복사를 피하기 위해
[Copy-on-write](http://en.wikipedia.org/wiki/Copy_on_write) 를 사용하는 방법으로
이 문제를 우회하기 시작했다.
COW 는 원천적으로 내용이 동등한 경우 실제 내용을 담고 있는 내부 객체를 공유하기 때문에
복사 문제를 해결할 뿐 아니라 메모리를 절약하는 추가적인 장점도 있어 널리 사용되었다.
다음은 COW 로 구현된 문자열의 복사생성자의 모습이다.

```cpp
CowString(const CowString& s) {
  Data* s_data = s.GetData();    // s 의 데이터를 가져옴
  s_data->IncRef();              // 데이터의 참조 카운트를 올리면서
  this->data = s_data;           // 공유
}
```

데이터 자체를 공유하기 때문에 객체 복사/소멸 때 추가적인 힙 작업이 없어 효율적이다.
하지만 이 방법은 문제를 해결하기 위해 동작 방식을 수정해야 하고
쓰레드 안전성을 위해 동기화 방법 제공해야 하는 등의 어려움이 있다.

한편 Andrei Alexandrescu 는 이 문제를 해결하기 위해
[Mojo](http://www.drdobbs.com/move-constructors/184403855)(Move of Joint Objects)
라는 패턴을 고안한다.
이 패턴은 임시 객체와 그렇지 않는 객체를 교묘하게 분리해서 처리하는 개념을 사용한다.

```cpp
class String : public mojo::enabled<string> {
  //...
  String(const String& rhs);            // 복사 생성자
  String(mojo::temporary<string> tmp);  // 임시변수를 가지고 생성
  String(mojo::fnresult<string> res);   //
}
```

괜찮은 구현이고 원하던 비효율 제거도 달성했으나 복잡한 구현의 클래스를 써야 한다는게 아쉽다.

컴파일러는 이와 별개로 리턴값 최적화([Named] [Return Value Optimization](http://en.wikipedia.org/wiki/Return_value_optimization))을 도입한다.
이 최적화는 함수가 반환하는 객체의 타입과 그걸 받아서 생성되는 객체의 타입이 일치하면
임시 객체를 만들지 않고 바로 받아서 생성될 객체에 직접 작업을 하는 최적화다.
위의 String operator + 의 경우 리턴값 최적화를 사용하면 아래와 같이 로컬 변수 r 없이 바로 실행된다.

```cpp
String x("head"), y("tail");
String s;                // operator + 의 r 대신 s 를 바로 사용
s.len, buf = run_operator +;
```

임시 변수 없이 깔끔하게 실행되는 것을 볼 수 있다.
다만 이 리턴값 최적화는 한계가 있는데 결과값으로 생성되는 경우에만 사용할 수 있다는 것과
함수 내에 반환될 수 있는 변수가 2개 이상이면 사용할 수 없다는 것이다.

```cpp
String s;
s = x + y;               // 대입 연산에는 RVO 를 사용할 수 없다

String function(...) {   // 리턴 가능한 변수가 2개라 RVO 불가
  if (...) {
     String r1 = ...;
     return r1;
  } else {
     String r2 = ...;
     return r2;
  }
}
```

이 구현은 컴파일러 마다 제각각이었으나 C++11 에서 [Copy Elision](http://en.cppreference.com/w/cpp/language/copy_elision)
으로 표준화 한다.
그리고 C++11 은 복사 문제를 위해 [우측값](http://en.cppreference.com/w/cpp/language/value_category)과 
[이동 생성자](http://en.cppreference.com/w/cpp/language/move_constructor)를 도입한다.

## 우측값(Rvalue), 이동 생성자

개념은 간단하다. 넘겨 받은 객체가 곧 소멸될 거라면 그 객체의 내용을 가져다 쓰자는 것이다.
이 방법으로 위 문자열 예제 코드를 아래처럼 구현해볼 수 있다.

```cpp
String x("head"), y("tail");
String r;                         // operator + 함수의 로컬 변수
r.(len, buf) = run_operator +;
String s;
s.(len, buf) = r.(len, buf);      // r 의 내용을 s 로 가져옴
r.(len, buf) = (0, nullptr);
r.~String();                      // r 소멸
```

힙 할당까지 해서 어렵게 만든 r 의 버퍼를 s 에 복사하고 버리는 것이아니라 옮겨오고
대신 r 은 빈 버퍼를 넣어준다.
어차피 소멸될 변수이기 때문에 소멸자만 잘 불리는 정도로 마무리 해놓고 내용을 다 들고 온다.
이제 r 을 만들면서 힙에서 할당해 놓은 버퍼를 s 가 그대로 가져갔으니
임시 객체가 한번 생성/소멸 발생하지만 힙의 추가 작업이 없으니 괜찮은 방법이라고 할 수 있다.

이 방법을 C++ 에서 문법적으로 지원해주는 것이 우측값과 이동 생성자이다.
우측값은 곧 소멸될 값의 의미로 사용하고 그 우측값을 사용해서 객체를 생성할 수 있도록
이동 생성자를 만들어 주었다.
복사생성자와 이동생성자는 다음과 같다.

```cpp
class String {
  String(String&& s) {                    // 이동 생성자
    len = s.len; buf = s.buf;
    s.len = 0;   s.buf = nullptr;
  }
  //...
```

우측값을 String&& 의 형태로 표현한다. 우측값을 인자로 받는 이동 생성자는 복사 생성자와
달리 인자로 받은 변수의 내용을 훔쳐오는 것을 볼 수 있다. 이동 생성자가 있으니 이동 대입
연산자도 있다. 이동 대입 연산자도 값을 훔쳐오는데 특히 이때는 swap 을 사용하면 편리하다.
이 작업은 (1) this 의 내용을 지우고 (2) 우측값으로 받은 변수의 내용을 가져오고
(3) 우측값이 잘 소멸되도록 빈 값을 넣는 과정으로 이루어져 있는데 이 것을 swap 으로 처리하면
간편하게 해결할 수 있다.
그래서 이동 할 때 swap 을 많이 사용한다.

```cpp
class String {
  String operator = (String&& s) {        // 이동 대입 연산자
    swap(len, s.len);
    swap(buf, s.buf);
  }
  //...
```

이제 문자열의 예는 아래 처럼 컴파일러가 경우에 따라 처리 해준다.

```cpp
String x("head");
String y(x);        // 복사 생성자 호출
String s(x + y);    // s(t = x + y) 이동 생성자 호출
```

간단하다! 이제 불필요한 복사도 없고 기분이 좋다! 우측값은 간단히 곧 소멸될 임시변수고
우측 생성자/대입연산자는 그런 우측값을 받아서 내용을 옮겨와 낭비를 없엔다 라고 생각하면 된다.
그런데 이게 전부가 아니다.

## std::move

문자열을 받아 문자를 모두 소문자로 만들어 반환하는 함수 lower 가 있다.
구현은 아래 코드처럼 되어 있다.

```cpp
String lower(const String& s) {
   String r(s);
   for (size_t i=0; i<r.len; i++)
     r.buf[i] = tolower(r.buf[i]);
   return r;
}
```

살펴보니까 lower 에 넘겨온 인자 s 가 우측값이라면 굳이 임시변수 r 을 새로 생성하지 말고
s 를 바로 사용하면 되지 않을까? 라고 생각해서 아래와 같은 함수를 하나 더 만들었다.

```cpp
String lower(String&& s) {
   String r(s);
   //...
}
```

자 이제 s 가 우측값으로 r 의 이동생성자에게 잘 넘어가서 오버헤드가 없기를 기대했다.
하지만 기대를 져버리고 복사 생성자가 호출된다. 왜냐하면 우측값이 이름을 가지게 되면
더 이상 우측값이 아니기 때문이다. (이름을 가지면 우측값일 수 없어서)
그렇다면 우측값으로 다시 만들어줘야 하는데 그럴 때 std::move 를 사용한다.
 함수의 반환 값은 이름이 없기 때문이다. 다음과 같이 컴파일러에게 우측값임을 다시 일러준다.

```cpp
String lower(String&& s) {
   String r(std::move(s));
   //...
}
```

자 이제 원하는대로 r 의 이동생성자가 호출된다.
이런 경우는 멤버 변수의 우측 생성자를 불러 줄 때 흔하게 발생한다.
아래 stack 생성자가 그런 경우에 해당한다.
stack 는 deque 를 멤버 변수로 가지고 있고 deque 의 이동생성자의 인자로 받은 s 가
더 이상 우측값이 아니기 때문에 std::move 로 s.c 를 우측값으로 만들어 두고
c 에게 넘겨야 원하는 대로 동작한다.

```cpp
template<class T>
class stack {
  //...
  stack(stack&& s)
    : c(std::move(s.c)) {  // 멤버변수 c 도 이동 생성자가 불리도록
    }
protected:
  deque<T> c;
};
```

언제 우측값인지 언제가 아닌지 잘 구분할 필요가 있다. 다음!

## std::forward

자 이제 클래스를 하나 만들면 할일이 두 배로 는 것 같이 보인다.
예로 든 lower 함수를 보면 const T& 타입의 인자를 받는 함수와 T&&
타입의 인자를 받는 함수 이렇게 두 벌이 있다.
하지만 내용이 동일하니까 어떻게 한 벌로 만들 수 있지 않을까?
차이라면 아래 코드처럼 임시변수 r 에 move 썼느냐 아니냐의 차이 밖에 없으니까.

```cpp
String lower(const String& s) {
   Str r(s);
   //...
}

String lower(String&& s) {
   Str r(std:move(s));
   //...
}
```

이 것을 아래처럼 template 으로 하나로 합친다.

```cpp
template <typename T>
String lower(T&& s) {
   String r(std::forward<string>(s));
   //...
}
```

여기서 lower 의 인자 T&& 는 특별한 의미를 가지는데 만약 T 가 T& 타입이라면 T& 로 해석되고
T&& 타입이라면 T&& 로 해석이 된다.
이걸 [Reference collapsing rules](http://msdn.microsoft.com/en-us/library/dd293668.aspx) 이라고 부른다.

자 이제 인자 s 는 넘겨 받은 인자가 String&& 타입이면 String&& 으로 동작하고
그렇지 않은 경우에는 const String& / String& 타입으로 동작한다.
이제 두번째로 필요 한 것은 std::forward 다. 이 함수는 s 가 우측값으로부터 왔다면
move 가 불리고 그렇지 않다면 아무 것도 하지 않는다.
따라서 임시 변수 r 은 s 가 우측값이면 이동 생성자가 불리고 그렇지 않으면 복사 생성자가 불리게 된다.
힘들게 함수 하나로 만들었다.

STL 에서 이 forward 사용하는 코드를 make_shared 에서 찾아볼 수 있다.
이 템플릿 함수는 shared_ptr 을 만들어주는 함수인데 shared_ptr 에게 넘겨줄 인자를
A&& 타입으로 받고 이것을 실제 생성자에게 넘겨준다.
이렇게 해둠으로써 복사 혹은 이동 생성자가 상황에 맞춰 불릴 수 있다.

```cpp
template<typename T, typename A>
shared_ptr<T> make_shared(A&& arg) {
  return allocate_shared<T>(allocator(), std::forward<A>(arg));
}
```

이것을 perfect forwarding 이라고 부른다.

## 결론

자. 시작부터 끝까지 내용이 많은 것 같지만 사실 리턴 값으로 결과 값을 넘기면서 발생하는
불필요한 객체 복사 작업을 없에기 위해서 고생고생 하는 내용이다.
덕분에 C++ 방식으로 깔끔하게 쓰면서도 효율을 유지하는 C++ 의 철학이 어느정도 (이제야) 지킬 수 있게 되었다.
하지만 필요 이상으로 복잡한 내용을 알아야 정확한 동작을 이해할 수 있다는 점에 대해서는 아쉽다.
([Rvalue ref. for \*this](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2439.htm) 는 글에서 언급하지도 않았다)

참고로 위에서 예로 들었던 lower 는 사실 아래처럼 써도 (C++11 에서) 효율적으로 동작한다.
함수 lower 가 불릴 때 임시로 생성되는 인자 s 는 우측값을 받았을 때 알아서 이동 생성자로 부터 생성되기 때문이다.

```cpp
String lower(String s) {
   for (size_t i=0; i<s.len; i++)
     s.buf[i] = tolower(s.buf[i]);
   return s;
}
```

이번 글에서는 대략적인 흐름만 다뤘을 뿐 실제 문법과 관련된 자세한 내용은 다루지 않았다.
자세한 내용을 읽고 싶다면 아래 링크의 글들을 읽어보는 것을 추천한다.

- Howard E. Hinnant, "[A Brief Introduction to Rvalue References](http://www.artima.com/cppsource/rvalue.html)"
- Scott Meyers, "[Move Semantics, Rvalue References and Perfect Forwarding](http://www.aristeia.com/TalkNotes/ACCU2011_MoveSemantics.pdf)"
- Thomas Becker, "[C++ Rvalue References Explained](http://thbecker.net/articles/rvalue_references/section_01.html)"
- Alex Allain, "[Move semantics and rvalue references in C++11](http://www.cprogramming.com/c++11/rvalue-references-and-move-semantics-in-c++11.html)"
- Mikhail Semenov, "[Move Semantics and Perfect Forwarding in C++11](http://www.codeproject.com/Articles/397492/Move-Semantics-and-Perfect-Forwarding-in-Cplusplus)"
- Pete Isensee, "[Faster C++: Move Constructors and Perfect Forwarding](http://pkisensee.wordpress.com/2012/03/09/faster-c-move-constructors-and-perfect-forwarding/)"
