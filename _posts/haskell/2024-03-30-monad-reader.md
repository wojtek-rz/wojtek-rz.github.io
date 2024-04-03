---
title: "Global variables in Haskell with MonadReader!"
categories:
  - blog
tags:
  - Haskell
  - Monads
  - Functional programming
---

# What is Monad Reader in Haskell? 
Understanding the `MonadReader` class in Haskell can be challenging.
Online tutorials often focus on implementation details rather than its purpose and usefulness. 
By the end of this post, you'll have a clear understanding of how MonadReader streamlines 
environment passing in Haskell, making your code cleaner and more maintainable. 

### Motivation

The term 'monad reader' comes from the idea that all functions read from a common source. 
  
For example, suppose you have a global configuration variable that several functions read from. 
By using a MonadReader, you can avoid passing that configuration as an argument to each function.
The result of our monad would be a function takes this global variable as an argument and 
then passes it to each function within it.

Here is a simple example. Suppose we are calculating the total cost of a trip to Europe. 
We visit three countries, each with its own currency: 
GBP in the UK, EUR in France and CHF in Switzerland.

```haskell
type ExchangeRate = String -> Double
exchangeRateToPln :: ExchangeRate
exchangeRateToPln "EUR" = 4.3
exchangeRateToPln "GBP" = 4.9
exchangeRateToPln "CHF" = 3.9
```
We want to pass a dictionary of currency rates to any function that needs them. 
The functions can have different numbers of arguments, 
but they have one thing in common - __the last argument is of type `ExchangeRate`__. 
(the implementation is not important here).

```haskell
getSwitzerlandCost :: Int -> Double -> ExchangeRate -> Double
getSwitzerlandCost days nightCost rate = fromIntegral days * nightCost * rate "CHF"

getUKCost :: Double -> ExchangeRate -> Double
getUKCost flightCost rate = 2.0 * flightCost * rate "GBP"

getFranceCost :: Double -> Double -> ExchangeRate -> Double
getFranceCost distance fuelCost rate = 2.0 * distance * fuelCost * rate "EUR"
```

Calculating the total cost is now straightforward:

```haskell
calculateTotalCost :: ExchangeRate -> Double
calculateTotalCost exchangeRateToPln = 
    let switzerlandCost = getSwitzerlandCost 7 100.0  exchangeRateToPln
        ukCost          = getUKCost 200.0             exchangeRateToPln
        franceCost      = getFranceCost 1000.0 1.5    exchangeRateToPln
        in (switzerlandCost + ukCost + franceCost)
```

Maybe we could get rid of the repetitive `exchangeRateToPln`? That's what
Monad Reader does. It hides the last argument of each function call,
so that it behaves like an abstract global variable that is passed unchanged to every
to any function in our monad. It is often called the `config` or `environment` argument.
The syntax of our monad is as follows:

```haskell
calculateTotalCost :: ExchangeRate -> Double
calculateTotalCost = do
    switzerlandCost <- getSwitzerlandCost 7 100.0
    ukCost <- getUKCost 200.0
    franceCost <- getFranceCost 1000.0 1.5
    return (switzerlandCost + ukCost + franceCost)
```

What if we want to write something like `gifts <- 100`? The `100` is a value, 
not a function that takes `ExchangeRate` as its last argument. We would write
`gifts <- return 100` and that's the monadic way to do it.

Believe it or not, but in the last code example we actually used a MonadReader.
The monadic type here is `ExchangeRate -> Double`, but we can abstract away
the implementation details here and write it with the `Reader` constructor
from `Control.Monad.Reader` library:
```haskell
calculateTotalCost :: ExchangeRate -> Double
-- is the same as
calculateTotalCost :: Reader ExchangeRate Double
-- in general:
-- Reader Env(last argument of functions / environment) Value(return value of the monad) 
```

What if we want to store `Environment` value in a "variable"? That's what identity function does:
```haskell
calculateTotalCost = do
    exchangeRate <- (\x -> x)
```

We can also run some function with changed environment. The most popular use case is when writing interpreters, 
but let's say we want to calculate the cost of our trip if the economic crisis were to hit.

```haskell
changeToCrisisRates :: ExchangeRate -> ExchangeRate
changeToCrisisRates rates currency = 2 * rates currency

calculateTotalCostWhenCrisis :: ExchangeRate -> Double
calculateTotalCostWhenCrisis = do
    rates <- id
    return (calculateTotalCost (changeToWarRates rates))
```

Here we have a function that changes the environment `changeToCrisisRates :: ExchangeRate -> ExchangeRate` 
and we run the `calculateTotalCost` calculation with the modified environment.

These two applications are so common,
that they deserve separate functions within the MonadReader class:
```haskell
ask :: Reader Env Env 
-- monad that returns Env
local :: (Env -> Env) -> (Reader Env Val) -> (Reader Env Val) 
-- Given a function to modify Env and current calculation,
-- return calculation that would run with modified Env.
```
Type `Env` denotes the environment type, which in our example
is `ExchangeRate`.

Another useful function is `asks` which helps with the problem: what if I want to get 
only part of Env, not the whole Env.

```haskell
asks :: (Env -> a) -> Reader Env a
-- given Env selector, create calculation that 
-- runs selector on Env and returns the value
```

### Implementation details

Let's try to implement this monad. What is a monadic type here?
Remember, that left arrow `<-` notation is a syntax for `>>=` with lambda expressions:

```haskell
calculateCost = do
    value <- getUKCost 200.0
    return value

-- is equal to
calculateCost = do
    getUKCost 200.0 >>= (\value -> return value)
```

So `getUKCost 200.0` is of type `ExchangeRate -> Double` which should be our monadic 
value. More generally, if `m` is our monad we would like to have:
```
m a == Env -> a
```
So here, the monad is a function, that takes environment and returns a value. 
A useful interpetation is that monads are containers for some values.
How can a function be a container? Actually, if we have a function `\_ -> 10'
then no matter what we give it as an argument we will get 10. 
This makes it 100% certain to hold the value 10. How do we chain such monads?
We would like to implement bind function with type:
```haskell
(>>=) :: m a -> (a -> m b)
(>>=) :: (Env -> a) -> (a -> (Env -> b))
```
It takes a monadic value with type `m a` and passed the value `a` to the function,
which returns the monadic value `m b`. But to get value `a` from monad 
`Env -> a` we have to pass `Env`. And that's exacly how we implement it:
```haskell
h >>= f = \w -> f (h w) w
```
We get the value from `h` with `h w` and pass it to `f`. Because the result of bind
must also have monadic value `m b == Env -> b`, and the result of `f` is a value
inside the function container, we have to pass again `w` to the result `f (h w)` to 
get the value inside the monad.

And even pure arithmetic has an interesting interpretation. It is a calculation
that ignores the result and always returns the value.

```haskell
return a = \_ -> a
```

In many places you will see such implementation:

```haskell
instance Monad ((->) r) where
    return x = \_ -> x
    h >>= f = \w -> f (h w) w
```

where the most confusing part is this `((->) r)`. This is type constructor which
is missing the argument - value it will take. With list monad we have:

```haskell
instance Monad [] where
    xs >>= f = concat $ map f xs
    return x = [x]
```

and `[]` is a constructor that is also missing value. For example if we write `[] Int`,
we give the type constructor `[]` type `Int` and the result is `[Int]`. So we can say that
`[]` is of _kind_ `* -> *`, where `*` is a type. Even more, `(->) r` is also a type
constructor of kind `* -> *`. If we give it the type `String` we get `(->) r String` which
can be also written as `r -> String`. In the Haskell documentation, `m = (->) r`, so `m`
is a monad type constructor. Therefore `m a` expands to `r -> a`.

Useful exercises are writing `functor` and `applicative` instances for the monad function, 
as well as `ask` and `local` functions (I explained what they do in the previous section). 
These implementations are:

```haskell
class Monad m => MonadReader r m | m -> r where
    ask :: m r -- we now now that m r expands to r -> r, so only id fits
    ask = id
    local :: (r -> r) -> m a -> m a
    local f previousReader env = previousReader (f env)
```

And that is how we can play with MonadReader.