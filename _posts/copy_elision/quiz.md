```
struct Foo{};

Foo createNewFooObject() {
    return Foo{};
}

int main() {
    auto foo = createNewFooObject();
    return 0;
}
```
what should be called?
- copy constructor
- move constructor
- none
