#include <stdio.h>

int test (int n)
{
  int total = 0;

  for (int i = 0; i < n; i++)
    total += i * i;

  return total;
}

int main(){
  test(5);
  return 0;
}