# data-adaptive_truncation

## Abstract
Estimation of causal parameters, such as mean counterfactual outcomes, is hard when individuals in the sample with low propensity scores belong to areas of the target population with large weight. In such settings, the variance of the canonical gradient of the target parameter is large or non finite (weakly identifiable target parameter). As a result an asymptotically linear estimator of the target parameter either does not exist, or has large asymptotic variance.

Existing approaches to deal with this issue trade-off variance and bias. One class of methods reduces variance by carefully choosing which predictors to include in the propensity score calculation. Another type of approach directly truncate the propensity score at a given fixed value, so as to lower bound it away from zero.

Truncation is often considered inevitable but the resulting estimators do not provide valid inference (coverage of the confidence intervals is bad), as we explain and illustrate with simulations.

We propose an algorithm to data-adaptively select the truncation level, and an estimator based on this truncation level. This latter has asympotically optimal convergence rate to the counterfactual mean outcome. We propose an extension of this algorithm for finite sample sizes, which using a truncation rule determined by an ensemble learning algorithm.

## Organization
The finite sample rule is obtained by ensemble learning. More specifically:
We sample from a prior a large number of distributions of the observed data. 
For each of these:
- we compute the optimal rate in sample size of the truncation level
- we generate a sample with random size
- we extract features (around 400) from the sample.
This generates a dataset with the optimal truncation rate as outcome and the features observable from the sample as predictors.
This data generation process is implemented in find_rate-generate_datasets.R, find_gamma-functions.R, find_beta-functions-no_bootstrap.R.

The rule is inferred using ensemble learning (find_rate-regression.R).

The asymptotically optimal rule is implemented in asymptotically_optimal_data-adaptive_truncation.R.

A simulation using the finite sample rule is implemented in TMLE_delta_n.R.


