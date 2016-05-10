---
layout: post
title: C++11 Variadic 삼형제
date: 2012-11-10
categories:
  - cpp
lang: ko
---

C++11 에 C99 의 [Variadic macro](http://en.wikipedia.org/wiki/Variadic_macro) 가
포함되고 새롭게 [Variadic template](http://en.wikipedia.org/wiki/Variadic_templates) 이
추가되어 C++11 의 [Variadic](http://en.wiktionary.org/wiki/variadic) 은
전통의 [Variadic function](http://en.wikipedia.org/wiki/Variadic_function) 까지
포함해 총 세 가지가 되었다.
각각의 사용법, 특징을 알아보자.

## Variadic function (가변 인자 함수)

가변 인자 함수는 아래와 같이 사용한다. va_start 로 가변 인자 커서를 만들고
그 커서를 사용해 va_arg 로 값 참조 및 커서 이동을 수행한다.
(일반적으로 가변 인자는 단순한 스택 접근으로 구현되어 있다.)

```cpp
void write(int count, ...) {
  va_list args;
  va_start(args, count);
  while (count-- > 0)
    puts(va_arg(args, const char *));
  va_end(args);
}
```

인자 순회가 간단한데 반해 받은 가변 인자를 그대로 다른 가변 인자 함수에게 넘길 수 있는 방법은 없다.
하지만 아래처럼 va_list 타입의 인자는 넘길 수 있다.

```cpp
int vprintf(const char* fmt, va_list arg);
void error(const char* fmt, ...) {
  puts("ERR:");
  va_list args;
  va_start(args, fmt);
  vprintf(fmt, args);
  va_end(args);
}
```

때문에 C 표준 가변 인자 함수들은 printf 와 vprintf 와 같이 ... 를 인자로 하는 함수와
va_list 를 인자로 하는 함수 이렇게 두 벌이 제공된다.
가변 인자는 최소 1개 이상의 고정 인자가 필요하다.
va_start 에 마지막 고정 인자를 넘겨야 하기 때문이다.
va_start 는 이 고정 인자가 스택의 어느 위치에 있는지를 확인 하고 그 다음부터
가변 인자가 있다고 판단하기 때문에 고정 인자가 필요하다.
가변 인자를 넘겨 받은 함수에서 인자 개수를 알 방법이 없다.
때문에 위 예제처럼 count 를 넘기거나 printf 처럼 포맷 문자열에서 추정하거나
[sentinel 값](http://en.wikipedia.org/wiki/Sentinel_value)을 사용한다.
하지만 이 방법 모두 올바르게 사용되지 않았을 때 알아낼 방법이 없다.
때문에 종종 버그의 원인이 된다.

```cpp
write_a(3, "a", "b", "c");            // 인자 개수를 넘김
write_b("%s %s %s", "a", "b", "c");   // 포맷 문자열로 추정
write_c("a", "b", "c", NULL);         // Sentinel 값 사용
```

가변 인자 함수는 넘겨 받은 인자의 타입을 알 수 있는 방법이 없다.
printf("%s", 1) 과 같이 형식 문자열과 실제 인자가 일치하지 않으면 크래시가 될 수도 있다.
다행히 gcc 는 컴파일 시점에 형식 문자열과 인자가 일치하는지 확인하는 기능이 있다.
컴파일 옵션에 [-Wformat](http://gcc.gnu.org/onlinedocs/gcc-4.7.2/gcc/Warning-Options.html) 등을
넣으면 이 기능을 사용할 수 있다.

```cpp
printf("%s", 10);   // warning: format '%s' expects argument of ...
printf("%d");       // warning: format '%d' expects a matching ...
printf("%d", 1, 2); // warning: too many arguments for format ...
```

C++11 에는 다음과 같이 [std::initializer_list](http://en.cppreference.com/w/cpp/utility/initializer_list)를
사용해 가변 인자 함수를 흉내낼 수 있다. 

```cpp
void write(std::initializer_list<const char*> strs) {
  for (auto s : strs)
    std::cout << s << std::endl;
}
write({"a", "b", "c"});
```

이 방법은 인자들 모두 같은 타입을 가져야 하는 제약이 있지만 인자 개수,
타입 제한이 가능해 좀 더 안전하고 편리하게 사용할 수 있다.

## Variadic macro (가변 인자 매크로)

C99 이전의 C/C++ 에서는 매크로에서 가변 인자를 사용할 수 있는 방법이 없었다.
때문에 가변인자가 필요한 경우에는 인자 개수별로 매크로를 만드는 방법을 사용했다.

```cpp
#define PRINT_1(fmt,a) printf((fmt), (a))
#define PRINT_2(fmt,a,b) printf((fmt), (a), (b))
#define PRINT_3(fmt,a,b,c) printf((fmt), (a), (b), (c))
```

작성하기도 사용하기도 불편한 문제를 해결하기 위해 C99 에서 가변 인자 매크로가 추가되었다.
(C++11 에도 추가되었다)

```cpp
#define PRINT(fmt,...) printf(fmt, __VA_ARGS__)
```

가변 인자 매크로는 보통 받은 가변 인자를 그대로 넘기는 용도로 사용한다.

```cpp
#define ERROR(fmt,...) \
  puts("ERR:"); printf(fmt, __VA_ARGS__)
```

가변 인자 함수로는 어려웠던 인자 넘기기가 쉽게 된다.
여기서 C99 에서 가변 인자 매크로를 추가한 목적을 알 수 있다.
매크로의 가변 인자의 개수가 0 이 되는 것은 곤란할 수 있다.
위 ERROR 의 경우 printf 가 전개 될 때 , 가 짝이 안맞기 때문인데
이를 해결하기 위해 gcc 는 문법을 확장해 빈 인자일 때 옆 콤마를 제거하는 [\#\#](http://gcc.gnu.org/onlinedocs/gcc-4.7.0/cpp/Variadic-Macros.html#Variadic-Macros) 를 추가했다.
vc++ 는 그냥 빈 인자일 때 옆에 있는 콤마를 무조건 [제거한다](http://msdn.microsoft.com/en-us/library/ms177415.aspx).
둘 다 표준은 아니다.
가변 인자를 포워딩 하는 것은 간단하나 그 인자를 순회하는 것은 간단하지 않다.
우선 인자 개수는 아래와 같이 계산해 낼 수 있다.

```cpp
#define VA_NUM_ARGS(...) VA_NUM_ARGS_IMPL_((__VA_ARGS__,5,4,3,2,1))
#define VA_NUM_ARGS_IMPL_(tuple) VA_NUM_ARGS_IMPL tuple
#define VA_NUM_ARGS_IMPL(_1,_2,_3,_4,_5,N,...) N

#define TEST(...) printf("%d\n", VA_NUM_ARGS(__VA_ARGS__));
TEST("a", "b", "c"); // 3
```

개수 세기부터 간단하지 않으니 그 이상이 필요하다면
[boost preprocessor](http://www.boost.org/doc/libs/1_52_0/libs/preprocessor/doc/index.html) 를 사용하자.
아래는 인자의 개수와 두 번째 인자를 얻어내는 예다.

```cpp
#define TESTB(...) printf("%d %s\n", \
  BOOST_PP_VARIADIC_SIZE(__VA_ARGS__), \
  BOOST_PP_VARIADIC_ELEM(1, __VA_ARGS__));
TESTB("a", "b", "c"); // 3 b
```

## Variadic template (가변 인자 템플릿)

매크로와 마찬가지로 기존 템플릿도 가변 인자를 받지 못했다.
때문에 가변 인자가 필요한 템플릿의 경우 번거로운 작업이 필요했다.

```cpp
template <typename T1>
void print(T1 a) {
  cout << a << endl;
}
template <typename T1, typename T2>
void print(T1 a, T2 b) {
  cout << a << endl;
  cout << b << endl;
}
//...
print(1, "a"); // 1 a
```

반복적인 코드 작업이 번거롭기 때문에 보통 매크로를 사용해 문제를 우회하는데
복잡한 케이스는 아래와 같이 boost.preprocessor 를 사용해 해결할 수 있다.

```cpp
#define PRINT_BODY(Z,N,_) \
  cout << s##N << endl;
#define PRINT_FUNC(Z,N,_) \
  template<BOOST_PP_ENUM_PARAMS(N, typename T)> \
  void print(BOOST_PP_ENUM_BINARY_PARAMS(N, T, s)) { \
 BOOST_PP_REPEAT(N, PRINT_BODY, _); \
  }
BOOST_PP_REPEAT_FROM_TO(1, 10, PRINT_FUNC, 0)

print(1, "a"); // 1 a
```

하지만 이런 코드는 읽기에 썩 좋지 않은데이런 어려움을 해결하기 위해 C++11 는 가변 인자 템플릿을 추가했다.
가변 인자 선언은 아래와 같이 한다. (... 위치에 주의한다)

```cpp
template<typename... Args>
void print(Args... args) {
  //...
}
```

위 print 예제를 가변 인자 템플릿으로 구현하면 다음과 같다.
인자 순회를 재귀를 사용해 구현했다.
코드에 있는 args... 는 arg1, arg2, ..., argN 과 같이 확장된다.

```cpp
void print(const char* s) {
  cout << s << endl;
}
template<typename T, typename... Args>
void print(T s, Args... args) {
  cout << s << endl;
  print(args...);
}
```

재귀가 아닌 방식으로는 다음과 같이 구현할 수 있다.
단 아래 코드는 출력이 반대로 된다.
(pass 에 넘겨지는 인자의 평가 순서가 오른쪽에서 왼쪽이기 때문이다)
만약 순서가 반대로 되어도 관계 없다면 아래와 같은 형식을 사용해도 좋다.
아래 코드에서 f(args)... 는 f(arg1), f(arg2), ..., f(argN) 과 같이 확장된다.

```cpp
template<typename... Args> inline void pass(Args&&...) {}

template<typename... Args>
void print(Args... args) {
  auto f = [](const char* s) { cout << s << endl; return 1; };
  pass( f(args)... );
}

print("a", "b", "c"); // c b a
```

가변인자의 개수는 sizeof... 로 간단히 확인할 수 있다.
```cpp
template<typename... Args>
void count(Args... args) {
  cout << sizeof...(args) << endl;
}
count("a", "b", "c", "d"); // 4
```
