---
title:  "Inline-Specifier"
layout: post
---

# Understanding Inline
Often, during discussions with peers, I notice a common misunderstanding of what the `inline` specifier in C++ does, and I hope to clarify it with the following blog post

This post is motivated by a session at my university where the speaker incorrectly claimed that the purpose of the inline specifier is to instruct the compiler to inline a function call.

This blog post is going to delve into how the `inline` specifier affects the compilation and linking of a function and how it interacts with `static` and `extern`

**Do note that `inline` works slightly differently in C and C++, we will be focusing only on C++**

References:
- https://en.cppreference.com/w/cpp/language/inline
- https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2023/n4950.pdf
- https://linux.die.net/man/1/nm

Recommended:
- https://www.youtube.com/watch?v=HakSW8wIH8A

<br>




To reiterate, the purpose of the `inline` specifier is not to inline a function call, but rather to allow multiple definitions of a function by changing it's symbol binding to weak

Excerpt from cppreference.com
> Because the meaning of the keyword inline for functions came to mean "multiple definitions are permitted" rather than "inlining is preferred" since C++98, that meaning was extended to variables.

Let us have a look at 3 files


<table>
<tr>
<th>foo.hpp</th>
<th>a.cpp</th>
<th>b.cpp</th>
</tr>
<tr>
<td>
  
```cpp
// foo.hpp
#pragma once

#include <iostream>
void foo()
{
    std::cout << "foo" << std::endl;
}
```
  
</td>
<td>

```cpp
// a.cpp
#include "foo.hpp"
void bar()
{
    std::cout << "bar" << std::endl;
    foo();
}
```

</td>
<td>

```cpp
// b.cpp
#include "foo.hpp"
void bar(); 
int main()
{
    foo();
    bar();
}
```

</td>
</tr>
</table>


This is clearly going to lead to a ODR violation, because the `a.o` and `b.o` translation units are going to each have a definition of `foo` and the linker is going to throw an error

Excerpt of the error message

```
$ g++ a.cpp b.cpp -o a.out
/usr/bin/ld: /tmp/ccO4TaN4.o: in function `foo()':
b.cpp:(.text+0x0): multiple definition of `foo()'; /tmp/ccWL7RWW.o:a.cpp:(.text+0x0): first defined here
collect2: error: ld returned 1 exit status
```

And this is a significant challenge in sharing header only libraries and forces library managers to separate header and source files.

Now using the `inline` specifier on the function `foo` we will see how we are able to make this code work and ship out library `foo` as a header only library

<table>
<tr>
<th>foo.hpp</th>
<th>a.cpp</th>
<th>b.cpp</th>
</tr>
<tr>
<td>
  
```cpp
// foo.hpp
#pragma once

#include <iostream>
inline void foo()
{
    std::cout << "foo" << std::endl;
}
```
  
</td>
<td>

```cpp
// a.cpp
#include "foo.hpp"
void bar()
{
    std::cout << "bar" << std::endl;
    foo();
}
```

</td>
<td>

```cpp
// b.cpp
#include "foo.hpp"
void bar(); 
int main()
{
    foo();
    bar();
}
```

</td>
</tr>
</table>

```
$ g++ a.cpp b.cpp -o a.out
$ ./a.out 
foo
bar
foo
```

Now let's see how this works internally by compiling `a.cpp` and `b.cpp` into their corresponding object files and linking them


<table>
<tr>
<th>a.o</th>
<th>b.o</th>
</tr>
<tr>
<td>
  
```
$ g++ -c a.cpp -o a.o
$ nm -C a.o
0000000000000000 T bar()
0000000000000000 W foo()
```
Note that the relative address of `bar` is 0, while that of `foo` is not yet set because it is a weak symbol, courtesy of the `inline` specifier

Weak symbols have there address deduced at link time 
  
</td>
<td>

```
$ g++ -c b.cpp -o b.o
$ nm -C b.o
0000000000000000 T main
                 U bar()
0000000000000000 W foo()
```

`main` has address of 0, while address of `foo` is 0 because it is not yet set because it is a weak symbol, courtesy the `inline` specifier

There is no address of `bar`, because we it is an undefined symbol

</td>
</tr>
</table>


Once the object files are linked and executed, we get the expected output

```
$ g++ a.o b.o -o main
$ ./main 
foo
bar
foo
```

Analyzing the symbol table of the executable we find out
```
$ nm -C main | grep foo
000000000040116e W foo()
$ nm -C main | grep bar
0000000000401146 T bar()
```

Only one definition of `foo` exists, the linker chooses only one of the definitions of the function, also do not that the address of `foo` is now defined

**Which one does it choose?**

It happens to choose the first 

Because we used the command `g++ a.o b.o -o main` it would be the definition in a.o

`g++ b.o a.o -o main` would lead to the definition in `b.o` being used

Nevertheless, this is information a C++ programmer should never attempt to rely on because the C++ standard specifies that all definitions of an `inline` specified function need to be identical and it should not matter which definition of the function is used.

Excerpt from cppreference.com
> 1. There may be more than one definition of an inline function or variable(since C++17) in the program as long as each definition appears in a different translation unit and all definitions are identical.
> 2. It must be declared inline in every translation unit.


Now that we have understood how `inline` affects linking, we will try to understand how it affects compilation

The popular idea is that `inline` specifier requests the compiler to attempt to inline the function and if the compiler can not even attempt to inline the function a warning/error might be thrown.

But, in my experience I have never come across anything of that sort. Only tangible evidence that an error might be thrown is from the following excerpt of the ISO CPP standard

```cpp
static void f() {}
inline void it() { f(); } // error: is an exposure of f
```

But I have unfortunately not been able to reproduce this error, please do feel free to reach out to me if you have anything to say regarding this matter.

## How does `inline` interact with `static` and `extern`

Before trying to understand how the `inline` specifier interacts with `static` and `extern` we will try to understand what `static` and `extern` are.

`static` and `extern` are linkage specifiers which convey to the if the member has internal or external linkage.

Members with internal linkage are only accessible from other scopes in the same translation unit, while members with external linkage are accessible from scopes in other translation units along with the same translation unit.

Consider `file.cpp`
```cpp
// file.cpp
#include <iostream>

void large_function_name()
{
    std::cout << "from file.cpp" << std::endl;
}
```

On compiling to an object file and checking the symbol table we get

```
$ nm -C file.o
0000000000000000 T large_function_name()
```
The uppercase `T` signifies that the symbol is accessible to other translation units while linking (has external linkage).

On adding the `static` linkage specifier to function we observer that

```
$ nm -C file.o
0000000000000000 t foo()
```
The lowercase `t` signifies that the symbol is not accessible form other translation units (has internal linkage).

By default global functions have external linkage, hence using the `extern` specifier has no difference.

NOTE: `inline` is not a linkage specifier, hence like all global functions, `inline` functions also have external linkage. Hence, the capital `W`.

`static inline` specified functions have linkage identical to a `static` function.

`extern inline` specific functions have linkage identical to an `inline` function.

### **Why use `static inline` over `static`?**
Often header only libraries are annotate their functions with `static inline` over simply using `static` despite both having the same linkage.

The reason for this has to do with the differences in the compilation phase.

The most prominent (and only) reason I have am aware of is that `static` functions do throw a unused-function warning when compiled whereas `static inline` functions do not.

If you have found any other reasons to use `static inline` over `static` please do reach out to me.

### **Why use `static inline` over `inline`?**
Most of the arguments over using `static inline` over `inline` has to do with the arguments against using weak symbols.
A simple ChatGPT query seems to list out the all the reasons I would mention over here, so let's just skip that part.
