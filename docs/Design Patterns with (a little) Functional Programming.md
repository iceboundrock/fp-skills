# Design Patterns with (a little) Functional Programming

## Goal

To improve the design and programming skills of the team. 

## Glossary

* OOP \- Object-oriented programming  
* FP \- Functional programming  
* Design Patterns \- Refer to [Design Patterns: Elements of Reusable Object-Oriented Software](https://en.wikipedia.org/wiki/Design_Patterns)  
* SOLID \- [SOLID](https://en.wikipedia.org/wiki/SOLID) is a mnemonic acronym for five design principles intended to make object-oriented designs more understandable, flexible, and maintainable.

## Background

Functional programming features have been added to almost all programming languages in the past 10\~20 years. It progressively changes how we design our code.  
It is not optimal to ignore this trend and stick with the traditional design patterns.

### The essential of programming

About 50 years(1976) ago, Niklaus Wirth published a book: “**Algorithms \+ Data Structures \= Programs**”. The book was one of the most influential computer science books of the time and was extensively used in education.  
Mr. Wirth did point out the essential of programming. It is not about frameworks, design patterns, classes, objects or even languages. Programming is essentially about input, output (data structures) and transformations(algorithms) in between.

### Why (a little) functional programming?

OOP is still well understood in the team, we don’t need/want to introduce a dramatic pardram shift at once. On the other hand, OOP is very hard to master. Sometimes, even the best team may not be able to follow the OOP best practices. For example, the `Interface Segregation Principle` claims that we should `keep interfaces small so that users don’t end up depending on things they don’t need.` But the [S3Client](https://sdk.amazonaws.com/java/api/latest/software/amazon/awssdk/services/s3/S3Client.html) interface has more than 200 methods.  
Applying some FP techniques can simplify low level design/code. 

## Out of scope

Since FP usually doesn’t need to create objects, I would not talk about `Creational Design Patterns` but focus on `Structural` and `Behavioral` patterns.

## Basic Constructs of Functional Programming

### Functions

A function transforms an input value to an output value. `y = f(x)` , `f` is a function.

```java
int f(int x) {
  return x^2;
}
```

### Function Compositions 

We can compose multiple functions like: `y = (g ∘ f)(x) => g(f(x))`. But `x` and `y` can also be functions which means a function can return a function and accept functions as parameters.

```

```

## Structural Design Patterns

### Adapter

[OO Adapter Pattern](https://refactoring.guru/design-patterns/adapter)

map/flatMap