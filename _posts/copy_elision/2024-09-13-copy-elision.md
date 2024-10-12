---
title: "One Word on Copy Constructors"
categories:
  - blog
tags:
  - C++
  - Object Oriented Programming
---

Let's say we have this C++ class with all five constructors:

```cpp
class Foo {
private:
    int x;

public:
    // Default constructor
    Foo(int x) : x{x} { std::cout << "An object was created.\n"; }

    Foo(const Foo&) { std::cout << "Copy constructor called.\n"; }
    Foo(Foo&&) { std::cout << "Move constructor called.\n"; }

    Foo& operator=(const Foo&) { std::cout << "Copy assignment operator called.\n"; return *this; }
    Foo& operator=(Foo&&) { std::cout << "Move assignment operator called.\n"; return *this; }

    // Destructor
    ~Foo() { std::cout << "An object was destroyed.\n"; }
};
```

Now, let's examine this piece of code:

```cpp
Foo createNewFooObject() {
    Foo foo{5};
    return foo;
}

int main() {
    auto foo = createNewFooObject();
    return 0;
}
```

What output will the program produce? How often will the copy constructor be invoked?

Unfortunately, C++17 doesn't specify it clearly. Possible outputs include:

```bash
An object was created.
An object was destroyed.
```

```bash
An object was created.
Copy constructor called.
An object was destroyed.
```

```bash
An object was created.
Copy constructor called.
Copy constructor called.
An object was destroyed.
```

When I ran this code, the output was the first option. None of the copy constructors were called. So what rule governs this behavior?

# Copy Elision

The C++ compiler uses a technique called **copy elision**. 
It ensures that if some calls to copy constructors can be avoided, they are. 
But first, let's understand when a copy constructor is invoked.

## When the Copy Constructor is Called

> The copy constructor is called whenever an object is initialized (by **direct-initialization** or **copy-initialization**) from another object of the same type (unless overload resolution selects a better match or the call is elided), which includes.
> -- <cite>[cppreference](https://en.cppreference.com/w/cpp/language/copy_constructor)</cite>

While direct initialization is straightforward, initializing an object from an explicit set of constructor arguments (e.g., `T object(arg1, arg2, ...);`), copy-initialization is more nuanced. According to [cppreference](https://en.cppreference.com/w/cpp/language/copy_initialization), there are several scenarios:
1. `T object = other;` - A named variable is declared with an equal sign.
2. `f(other)` - Passing an argument to a function by value.
3. `return other;` - Returning from a function that returns by value.
4. `throw object; catch (T object)` - Throwing or catching an exception by value.

In the first code snippet, two copy constructors should be called: the first when returning from a function (3) and the second when declaring a variable with an equal sign (1). 

## Are There Guarantees?

Since C++17, there’s something called **guaranteed copy elision**.
It states:
> Since C++17, a prvalue is not materialized until needed, and then it is constructed directly into the storage of its final destination.
> -- <cite>[cppreference](https://en.cppreference.com/w/cpp/language/copy_elision)</cite>

It means, that even when the syntax suggests a copy constructor should be called, but the value that is the source of the copy is a prvalue, 
the compiler can optimize it away. The result is just a single constructor call in the final destination.

The documentation provides two examples of this guarantee:
1. When initializing an object in a return statement with a prvalue:
    ```cpp
    return Foo{5};
    ```
    This optimization was earlier called URVO - "unnamed return value optimization" and was a common optimization even before C++17, but is now a part of the standard. 

2. During object initialization when the initializer expression is a prvalue:
    ```cpp
    Foo x = Foo{Foo{Foo{5}}};
    ```
    Here, the fact that the constructors are chained together doesn't matter.
    It's worth noting that "move" assignments are elided, not "copy". 

Beyond that, the standard also specifies situations where the compiler **may** apply copy elision but isn’t obligated to, such as:
1. `return` statements with a named operand. 
   This optimization is called NRVO - "named return value optimization" and example of that was in the first code snippet.
   As we saw, most compilers implement this optimization, but it’s not mandatory.
2. Object initialization from a temporary.
3. `throw` expressions with a named operand.
4. Exception handlers.

For more details, check [cppreference](https://en.cppreference.com/w/cpp/language/copy_elision).

With the introduction of move semantics in C++11, the compiler can also elide move constructors the same way it does with copy constructors.
{:.notice--info}


## Some strange example

The compilers can be easily tricked when it comes to copy elision. 

Take this code for example:
```cpp
void throwFoo() {
    Foo foo{5};
    foo.printX();
    throw foo;
}

int main() {
    try{
        throwFoo();
    } catch(Foo foo){
        foo.printX();
        std::cout << "Caught an exception\n";
    }
    return 0;
}
```
The result is:
```
An object was created.
x: 5
A move constructor called.
An object was destroyed.
A copy constructor called.
x: 1600677166
Caught an exception
An object was destroyed.
An object was destroyed.
```
The code compiled without any warnings or errors. 
The output is unexpected, as the object is destroyed and then copied.
If there are any rules in the C++ that says I can't do that, they are not easy to find.
C++ reference only says [about the exception throwing](https://en.cppreference.com/w/cpp/language/throw):

> Let `ex` be the conversion result:
> * The exception object is copy-initialized from `ex`.

The exepction object wasn't copy-initialized, but moved-initialized and produced an undifined behavior.
If we changed the catch parameter to `const Foo& foo`, the output would be very simmiliar but the reported x value would be `0`.
If we would change `throw foo;` to `throw Foo{5};`, the move would be elided.

Maybe the conclusion is to always use `throw` with a temporary object, not a named one.

# Summary

Before C++17, copy elision was an optimization that compilers could apply, but it wasn't guaranteed. 
It could generate different results depending on the compiler and optimization level (like debug/release mode).
It's worth noting that the code that relies on possible optimizations like "named return value optimization" is not portable 
and can produce different results on different compilers.