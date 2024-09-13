#include <iostream>

class Foo {
private:
    int x;

public:
    // Default constructor
    Foo(int x) : x{x} { std::cout << "An object was created.\n"; }

    // Copy constructor
    Foo(const Foo&) { std::cout << "A copy constructor called.\n"; }
    Foo(Foo&&) { std::cout << "A move constructor called.\n"; }

    // Destructor
    ~Foo() { std::cout << "An object was destroyed.\n"; }

    // Copy assignment operator
    Foo& operator=(const Foo&) { std::cout << "A copy assignment operator called.\n"; return *this; }
    Foo& operator=(Foo&&) { std::cout << "A move assignment operator called.\n"; return *this; }
};

Foo createNewFooObject() {
    Foo foo{5};
    return foo;
}

// int main() {
//     auto foo = createNewFooObject();
//     return 0;
// }

void giveMeFoo(Foo foo){
}

// int main(){
//     Foo foo{5};
//     giveMeFoo(foo);
//     std::cout << "After function call\n";
//     return 0;
// }

void throwFoo(){
    throw Foo{5};
}

// int main(){
//     try{
//         throwFoo();
//     } catch(Foo foo){
//         std::cout << "Caught an exception\n";
//     }
//     return 0;
// }

Foo createNewFooObjectPrvalue() {
    return Foo{5};
}

// int main() {
//     auto foo = createNewFooObject();
//     return 0;
// }

int main() {
    giveMeFoo(Foo{5});
    return 0;
}

