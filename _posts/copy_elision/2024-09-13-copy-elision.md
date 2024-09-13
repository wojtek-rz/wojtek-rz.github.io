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

The C++ compiler uses a technique called **copy elision**. It ensures that if some calls to copy constructors can be avoided, they are. But first, let's understand when a copy constructor is invoked.

## When the Copy Constructor is Called

> The copy constructor is called whenever an object is initialized (by direct-initialization or copy-initialization) from another object of the same type (unless overload resolution selects a better match or the call is elided), which includes.
> -- <cite>[cppreference](https://en.cppreference.com/w/cpp/language/copy_constructor)</cite>

While direct initialization is straightforward, initializing an object from an explicit set of constructor arguments (e.g., `T object(arg1, arg2, ...);`), copy-initialization is more nuanced. According to [cppreference](https://en.cppreference.com/w/cpp/language/copy_initialization), there are several scenarios:
1. `T object = other;` - A named variable is declared with an equal sign.
2. `f(other)` - Passing an argument to a function by value.
3. `return other;` - Returning from a function that returns by value.
4. `throw object; catch (T object)` - Throwing or catching an exception by value.

In the first code snippet, two copy constructors should be called: the first when returning from a function (3) and the second when declaring a variable with an equal sign (1). But none are called. Let's explore the second and third cases.

```cpp
void giveMeFoo(Foo foo) {}

int main() {
    Foo foo{5};
    giveMeFoo(foo);
    std::cout << "After function call\n";
    return 0;
}
```

Output:
```
An object was created.
Copy constructor called.
An object was destroyed.
After function call
An object was destroyed.
```

When passing an argument to a function by value, the copy constructor is invoked as expected (a common performance issue for beginners). What about throw and catch?

```cpp
void throwFoo() {
    Foo foo{5};
    throw foo;
}

int main() {
    try {
        throwFoo();
    } catch(Foo foo) {
        std::cout << "Caught an exception\n";
    }
    return 0;
}
```
The result is:
```
An object was created.
Move constructor called.
An object was destroyed.
Copy constructor called.
Caught an exception
An object was destroyed.
An object was destroyed.
```

For the `throw` expression, the compiler chose the move constructor, and the `catch` statement invoked the copy constructor. If we change `throw foo;` to `throw Foo{5};`, the first move is optimized away.

To summarize:
1. `T object = other;` - Copy elided.
2. `f(other)` - Copy constructor called.
3. `return other;` - Copy elided.
4. `throw object;` - Copy partially elided; `catch (T object)` - Copy constructor called.

## Are There Guarantees?

Since C++17, there’s something called **guaranteed copy elision**. Two cases provide this guarantee:
1. When initializing an object in a return statement with a prvalue:
```cpp
return Foo{5};
```
2. During object initialization when the initializer expression is a prvalue:
```cpp
Foo x = Foo{Foo{5}};
```

In these scenarios, copy elision is guaranteed. Beyond that, the standard also specifies situations where the compiler **may** apply copy elision but isn’t obligated to, such as:
1. `return` statements with a named operand.
2. Object initialization from a temporary.
3. `throw` expressions.
4. Exception handlers.

For more details, check [cppreference](https://en.cppreference.com/w/cpp/language/copy_elision).

## Examples

Let's revisit the initial code:

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

The value returned by `createNewFooObject` isn’t a prvalue, so copy elision isn’t mandatory, but it’s a common optimization implemented by most compilers. This scenario is known as NRVO - "named return value optimization."

Consider a slight modification:

```cpp
Foo createNewFooObjectPrvalue() {
    return Foo{5};
}

int main() {
    auto foo = createNewFooObjectPrvalue();
    return 0;
}
```
Because the expression in `createNewFooObjectPrvalue` is a prvalue, copy elision is guaranteed. This specific optimization is called URVO - "unnamed return value optimization."

Another example:

```cpp
auto foo = Foo{Foo{Foo{5}}};
```
Here, because the right-hand side consists of prvalues, guaranteed copy elision applies. It's worth noting that "move" operations are elided, not "copy".

Finally:

```cpp
int main() {
    giveMeFoo(Foo{5});
    return 0;
}
```
This initializes a function parameter from a temporary. Though not mandatory, most compilers optimize this to avoid the copy constructor.

# Summary

In summary, we have:
### Guaranteed copy elision:
1. In return statements with a prvalue operand.
2. During object initialization with a prvalue expression.

### Non-mandatory copy elision:
1. In return statements with named operands.
2. Object initialization from unnamed temporaries.
3. `Throw` expressions and handlers.

In conclusion, while guaranteed contexts ensure no copies or moves are made, in other scenarios, copy constructors can still be invoked, especially when function arguments are passed by value.
