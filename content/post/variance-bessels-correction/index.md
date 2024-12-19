---
title: Math Typesetting
description: Why variance estimator is biased and how to correct it
date: 2024-11-01
math: true
---

In statistics, the variance is a measure of how far the values in a data set are spread out from the mean. 
It is caluclated as the average of **squared differences** from the mean. When calculating the variance of a sample, 
we divide by `n-1` instead of `n` to correct the bias. This is called **Bessel's correction** and is explained nicely 
[here](https://en.wikipedia.org/wiki/Bessel%27s_correction).

Before we dig into the details, let's first define some terms:
- **population** - the entire datasets of objects we are interested in
- **sample** - a subset of the population
- **an estimator** - a rule (commonly a formula) for estimating some quantity about the population (like mean, variance or some distribution parameter) based on the sample data
- **variance** - a measure of how far the values in a data set are spread out from the mean

Imagine our population is a set of `n` numbers: $x_1, x_2, \ldots, x_n$. The population mean and variance is calculated as:

$$
\mu = \frac{1}{n} \sum_{i=1}^{n} x_i
$$
$$
\sigma^2 = \frac{1}{n} \sum_{i=1}^{n} (x_i - \mu)^2
$$

where $\mu$ is the population mean. 

It is often impossible to collect data from the entire population. We can rewrite the equations above to the expected value form, where 
the population $x_1, x_2, \ldots, x_n$ is distributed as a random variable $X$:

$$
\mu = E[X]
$$
$$
\sigma^2 = E[(X - \mu)^2]
$$

## Estimators

In real life, we often have to estimate the population parameters from a sample. 
Let's say we have a sample of `n` numbers $x_1, x_2, \ldots, x_n$ distributed from the population - 
we would write it as 

$$
x_1, x_2, \ldots, x_n \sim X
$$

The mean estimator is calculated as:
$$
\bar{x} = \frac{1}{n} \sum_{i=1}^{n} x_i
$$

while the intuitive variance estimator is calculated as:
$$
s_n^2 = \frac{1}{n} \sum_{i=1}^{n} (x_i - \bar{x})^2
$$

## Bias of an estimator

When we say about the **bias** of an estimator, we mean the difference between the expected value of the estimator and the true value of the parameter being estimated. We have to calculate:
$$
E_{x_1, x_2, \ldots, x_n \sim X}[\bar{x}] \stackrel{?}{=} \mu
$$

$$
E_{x_1, x_2, \ldots, x_n \sim X}[s_n^2] \stackrel{?}{=} \sigma^2
$$

In the following sections, we will omit the $x_1, x_2, \ldots, x_n \sim X$ part of the expected value for brevity.

### Calculating the biasness of the estimators

To check, whether the mean estimator is biased, we can expand the expected value of the mean estimator:

$$
E[\bar{x}] = E\left[\frac{1}{n} \sum_{i=1}^{n} x_i\right] = \frac{1}{n} \sum_{i=1}^{n} E[x_i] = \frac{1}{n} \sum_{i=1}^{n} \mu = \mu
$$

But in the case of the variance estimator, the equations are not that simple. After many reordering and simplifications, we 
would get:
$$
E[s_n^2] = \frac{n-1}{n} \sigma^2
$$

This means that the variance estimator is biased. To correct this bias, we have to multiply the variance estimator by $\frac{n}{n-1}$. 
But isn't that counterintuitive? Why we have to divide the variance by `n-1` instead of `n`, to achieve an unbiased estimator?


## Intuition behind Bessel's correction

The problem with the $s_n^2$ estimator is that the sample mean $\bar{x}$ is used. 
It is also an estimation and is almost always not equal to the population mean $\mu$.
In fact, if they are not equal, then, the variance is calulated using the mean, that is closer to the sample values
and the resulting variance is smaller than the true variance.