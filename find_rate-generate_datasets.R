# Generate datasets to be used to learn a rule to infer 
# optimal rates from observable features.
# Sample from a prior a data generating distribution of the observed data.
# For each data-generating distribution, generate a sample of random size.
# Predictors are observable features. 
# Outcome is optimal rate, known as it is computable from the 
# data-generating distribution we sampled.

# running_environment <- 'SAVIO2'
running_environment <- 'AWS'
# Retrieve the command line arguments
if(running_environment == 'SAVIO2'){
  args <- commandArgs(TRUE)
  print(args)
  if(length(args)==0){
    print("No arguments supplied.")
    ##supply default values
    quit("no", 1)
  }else{
    for(i in 1:length(args)){
      eval(parse(text=args[[i]]))
    }
  }
}else{
  task_id <- 1
}
cat("Task id: ", task_id, "\n")

source('./find_gamma-functions.R')
source('./find_beta-functions-no_bootstrap.R')

if(running_environment == 'SAVIO2'){
  library(R.methodsS3, lib.loc = '~/Rlibs')
  library(R.oo, lib.loc = '~/Rlibs')
  library(R.utils, lib.loc = '~/Rlibs')
  library(Rmpi); library(doMPI)
}else if(running_environment == 'AWS'){
  library(R.methodsS3)
  library(R.oo)
  library(R.utils)
  library(foreach); library(doParallel)
}else{
  library(R.methodsS3)
  library(R.oo)
  library(R.utils)
  library(Rmpi); library(doMPI)
}

# Sample data-generating distribution's parameters
sample_datagen_dist.parameters <- function(alpha0_max){
  # Define the vertices of a polytope of parameters (alpha0, lambda^-2, abs(beta2))
  # for which the target parameter is weakly identifiable
  vertices <- t(rbind(c(0, 0, 0),
                      c(alpha0_max, 0, 0),
                      c(alpha0_max, alpha0_max, 0),
                      c(alpha0_max, 0, alpha0_max))) # One column per vertex
  # Pick uniformly the parameter vector (alpha0, lambda^-1, abs(beta2))
  # in the polytope defined by the above defined vertices
  unormalized_weights <- runif(4)
  weights <- unormalized_weights / sum(unormalized_weights)
  main_params <- as.vector(vertices %*% weights)
  alpha0 <- main_params[1]; lambda <- 1 / main_params[2]
  beta2 <- (1 - 2 * rbinom(1, 1, 0.5)) * main_params[3]
  
  beta0 <- runif(1, min = -2, max = 2)
  beta1 <- runif(1, min = -2, max = 2)
  gamma <- (alpha0 - 1 / lambda - abs(beta2)) / (2 * alpha0)
  
  list(lambda = lambda, alpha0 = alpha0, beta0 = beta0, beta1 = beta1,
       beta2 = beta2, gamma = gamma)
}

# Generate beta and gamma datapoint
generate_datapoint <- function(plotting = F){
  
  # Sample a data generating distribution
  current_data_generating_distributions.parameters <- sample_datagen_dist.parameters(runif(1, min = 2, max = 10))
  beta <- (current_data_generating_distributions.parameters$alpha0 - 1 / current_data_generating_distributions.parameters$lambda -
             max(0, current_data_generating_distributions.parameters$beta2)) / current_data_generating_distributions.parameters$alpha0
  gamma <- current_data_generating_distributions.parameters$gamma
  n <- floor(10^runif(1, min = 3, max = 4.8))
  
  # Sample a dataset from the above sampled data-generating distribution
  observed_data <- generate_data("L0_exp", current_data_generating_distributions.parameters$lambda, 
                                 current_data_generating_distributions.parameters$alpha0, 
                                 current_data_generating_distributions.parameters$beta0, 
                                 current_data_generating_distributions.parameters$beta1, 
                                 current_data_generating_distributions.parameters$beta2, 
                                 n)
  
  # Compute the empirical variances of the IC at different values of the truncation level
  var_IC_df <- compute_variances(observed_data)
  var_IC.plot <- NULL
  #var_IC.plot <- plot_log_var_IC(var_IC_df)
  
  # Compute finite differences
  Delta.delta_rates <- c(0.8, 1, 1.1, 1.375, 1.5)
  fin_diffs_df <- compute_finite_difference(observed_data, Delta.delta_rates, n)
  
  # Extract gamma features
  gamma_features <- NULL
  cat('About to call extract_gamma_features')
  try(gamma_features <- extract_gamma_features(var_IC_df, gamma, plotting = F, var_IC.plot = var_IC.plot))
  
  # Extract bete features
  cat('About to call beta_features')
  beta_features <- NULL
  try(beta_features <- extract_beta_features(fin_diffs_df, beta, plotting = F))
 
  cat("gamma_features:\n")
  print(gamma_features)
  cat("beta_features:\n")
  print(beta_features)
 
  if(!is.null(gamma_features) & !is.null(beta_features)){
    return(cbind(gamma_features, beta_features))
  }else if(!is.null(beta_features) & is.null(gamma_features)){
    features <- matrix(NA, nrow = 1, ncol = 76 + 278)
    features[, 77:(76 + 278)] <- as.matrix(beta_features)
    return(features)
  }else if(!is.null(gamma_features) & is.null(beta_features)){
    features <- matrix(NA, nrow = 1, ncol = 76 + 278)
    features[, 0:76] <- as.matrix(gamma_features)
    return(features)
  }else{
    stop("Could extract neither beta nor gamma features")
  }
}

# debug(extract_gamma_features)
# debug(generate_datapoint)

# Set up cluster
if(running_environment == 'AWS'){
  cat(detectCores(), 'cores detected\n')
  cl <- makeCluster(getOption("cl.cores", detectCores()), outfile = '')
  registerDoParallel(cl)
}else{
  cl <- startMPIcluster()
  registerDoMPI(cl)
}
# Generate a bunch of datapoints and save them to a csv file
# Find out to which file to write
#file_number <- NULL
#while(file.exists(paste("rate_inference.features.results", file_number, ".csv", sep = ''))){
#  if(is.null(file_number)){
#    file_number <- 1
#  }else{
#    file_number <- file_number + 1
#  }
#}
outfile <- paste("rate_inference.features.results", task_id, ".csv", sep = '')
outfile_name.defined <- T
cat("We'll write results in ", outfile, "\n")

rate_inference.features_df <- vector()
for(i in 1:1e6){
  iteration.results <- NULL
  try(iteration.results <- generate_datapoint(plotting = F))
  
  # Write the results to outfile
  if(!is.null(iteration.results)){
    cat('Results:\n')
    if(!file.exists(outfile)){
      if(!is.na(iteration.results[1])){
	      iteration.results <- cbind(dataset_id = 1, iteration.results)
	      write.table(iteration.results, file = outfile, append = T, row.names = F, col.names = T,  sep = ",")
	}
    }else{
      n_lines <- countLines(outfile)[1]
      last_dataset_id <- read.csv(outfile, skip = n_lines - 2)[1]
      iteration.results <- cbind(dataset_id = as.numeric(last_dataset_id + 1), iteration.results)
      if(length(rate_inference.features_df) != 0) colnames(iteration.results) <- colnames(rate_inference.features_df)
      write.table(iteration.results, file = outfile, append = T, row.names = F, col.names = F,  sep = ",")
    }
  }
  rate_inference.features_df <- rbind(rate_inference.features_df,
                                      iteration.results)
}
closeCluster(cl)
