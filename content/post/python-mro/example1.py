class A:
    def m(self):
        print("method of A called")

class B:
    def m(self):
        print("method of B called")

class C(A,B):
    def check(self):
        self.m() # <--------  Which method will be called?

print("Class mro:", C.mro())