####################################
# Created by Tianchen Qian, 2018/8/29
#
# The code is based on SARAanalysis_20180824.R (on Tianchen's local laptop),
# and Tianchen updated the code to incorporate availability indicator.

# Note of code logic in handling availability:
# the availability indicator is always multiplied with the residual r := Y - exp(alpha*Z + beta*X)
# in estimating function and in asymptotic variance calculation

####################################
# Update by Tianchen Qian, 2018/9/25
#
# 1. Revised the code to allow individuals with different lengths of observations.
#    Argument change: removed "max_days" argument.
# 2. Revised the code to allow treatment indicator = NA, when availability = 0
# 3. Revised the code for primary hypothesis 2:
#    previously, the code used "no_intercept_for_moderator" to handle availability;
#    the updated version now handles availability in a more consistent way.
#    Argument change: removed "no_intercept_for_moderator" argument.

####################################
# Update by Tianchen Qian, 2018/10/22
#
# 1. Corrected a previous mistake in calculating degrees of freedom for t-test.
#    Now the degrees of freedom correctly takes into account the dimension of moderators.
# 2. Modified the output of SARA_exploratory_analysis() to include test results
#    of both t-test and F-test.

####################################
# Update by Tianchen Qian, 2018/11/1
#
# 1. Implement general F-test for linear combinations in SARA_exploratory_analysis_general_F_test().

####################################
# Update by Tianchen Qian, 2019/2/5
#
# 1. Changed from one-sided test to two-sided test in all t-tests

####################################
# Update by Tianchen Qian, 2019/3/21
#
# 1. Add alpha and alpha_se to the output.



library(rootSolve) # for solver function multiroot()

##########################################
# A utility function to find the change location of a vector.
# This is used to handle different length of observations among individuals.
# 
# example:
# v <- c("a", "a", "b", "c", "c"); find_change_location(v)
# [1] 1 3 4
find_change_location <- function(v){
    n <- length(v)
    if (n <= 1) {
        stop("The vector need to have length > 1.")
    }
    return(c(1, 1 + which(v[1:(n-1)] != v[2:n])))
}




binary_outcome_moderated_effect <- function(
        dta,
        control_var,
        moderator,
        id_var,
        day_var = "Day",
        trt_var = "A",
        outcome_var = "Y",
        avail_var = NULL,
        prob_treatment = 1/2,
        significance_level = 0.05)
{
    ############## description ###############
    ##
    ## This function estimates the moderated treatment effect for binary outcome,
    ## and provides variance estimate, test statistics (t-test and F-test), and p-values.
    ##
    ## It incorporates two methods for small sample correction:
    ## 1) the usage of "Hat" matrix in the variance estimate (as in Mancl & DeRouen 2001)
    ## 2) the usage of t-distribution or F-distribution critical value with corrected degrees of freedom
    ##    (as in Liao et al. 2015)
    ##
    ## It is used as an internal function for SARA analysis wrapper functions.
    ##
    ## Note: dta needs to be sorted by id_var then day_var
    ##       (currently this is handled in each of the wrapper functions)
    
    ############## arguments ###############
    ##
    ## dta.............the data set in long format
    ## control_var...........vector of variable names used to reduce noise (Z in the model),
    ##                       could be NULL (no control covariates)
    ## moderator.............vector of variable names as effect modifiers (X in the model),
    ##                       could be NULL (no effect modifier)
    ## id_var................variable name for subject id (to distinguish between subjects in dta)
    ## day_var...............variable name for day in study
    ## trt_var...............variable name for treatment indicator
    ## outcome_var...........variable name for outcome variable
    ## avail_var.............variable name for availability variable
    ##                       NULL (default) means always-available
    ## prob_treatment........probability of treatment (default to 1/2)
    ## significance_level....significance level for the hypothesis testing (default to 0.05)


    ############## return value ###############
    ##
    ## This function returns a list of the following components:
    ##
    ## beta_hat..............estimated beta
    ## alpha_hat.............estimated alpha
    ## beta_se...............standard error for beta_hat
    ## alpha_se..............standard error for alpha_hat
    ## beta_se_ssa...........standard error for beta_hat, with small sample correction (hat matrix)
    ## alpha_se..............standard error for alpha_hat, with small sample correction (hat matrix)
    ## test_result_t.........(two-sided) t-test result for each entry in beta_hat, which is a list consisting of test_stat, critical_value, p_value
    ## test_result_f.........F-test result for beta = 0, which is a list consisting of test_stat, critical_value, p_value
    ## varcov................estimated variance-covariance matrix for (beta_hat, alpha_hat)
    ## varcov_ssa............estimated variance-covariance matrix for (beta_hat, alpha_hat), with small sample correction (hat matrix)
    ## dims..................a list of p (dim of moderator) and q (dim of control_var), which includes the intercepts if added


    ############## part 1 :: preparation ###############
    
    # location of each individual's data in dta, when looping over individuals
    person_first_index <- find_change_location(dta[, id_var])
    if (length(person_first_index) != length(unique(dta[, id_var]))) {
        stop("The length of person_first_index doesn't equal the number of unique id_var's.")
    }
    person_data_location <- c(person_first_index, nrow(dta) + 1)
    
    # gather variables
    if (is.null(avail_var)) {
        avail <- rep(1, nrow(dta))
    } else {
        avail <- dta[, avail_var]
    }
    
    A <- dta[, trt_var]
    if (any(is.na(A[avail == 1]))) {
        stop("Treatment indicator is NA where availability = 1.")
    }
    A[avail == 0] <- 0
    
    cA <- A - prob_treatment # centered A
    Xdm <- as.matrix( cbind( rep(1, nrow(dta)), dta[, moderator] ) )   # X design matrix, intercept added
    Zdm <- as.matrix( cbind( rep(1, nrow(dta)), dta[, control_var] ) ) # Z design matrix, intercept added
    Y <- dta[, outcome_var]
    
    n <- sample_size <- length(unique(dta[, id_var]))
    
    p <- ncol(Xdm) # dimension of beta
    q <- ncol(Zdm) # dimension of alpha
    
    Xnames <- c("Intercept", moderator)
    Znames <- c("Intercept", control_var)
    

    ############## part 2 :: estimate beta and alpha ###############
    
    estimating_function <- function(theta) {
        # function to be used in solver
        # theta is a vector of length: length(control_var) + 2
        beta <- as.matrix(theta[1:p])
        alpha <- as.matrix(theta[(p+1):(p+q)])
        
        exp_Zdm_alpha <- exp(Zdm %*% alpha)
        exp_negAXdm_beta <- exp(- A * (Xdm %*% beta))
        residual <- Y * exp_negAXdm_beta - exp_Zdm_alpha
        
        ef <- rep(NA, length(theta)) # value of estimating function
        for (i in 1:p) {
            ef[i] <- sum( residual * avail * cA * Xdm[, i])
        }
        for (i in 1:q) {
            ef[p + i] <- sum( residual * avail * exp_Zdm_alpha * Zdm[, i])
        }
        
        ef <- ef / sample_size
        return(ef)
    }
    
    # if come across solver error, try change the initial values here
    beta_initial <- rep(0, p)
    alpha_initial <- rep(0, q)
    root <- multiroot(estimating_function, c(beta_initial, alpha_initial), useFortran = FALSE)
    if (p == 1) {
        beta_root <- root$root[1]
    } else {
        beta_root <- as.matrix(root$root[1:p])
    }
    if (q == 1) {
        alpha_root <- root$root[(p+1):(p+q)]
    } else {
        alpha_root <- as.matrix(root$root[(p+1):(p+q)])
    }
    
 
    ############## part 3 :: estimate standard error by asymptotics ###############
    
    # Compute M_n matrix (M_n is the empirical expectation of the derivative of the estimating function)

    Mn_summand <- array(NA, dim = c(nrow(dta), p+q, p+q))
    for (it in 1:nrow(dta)) {

        # this is to make R code consistent whether X_it, Z_it contains more entries or is just 1.        
        if (p == 1) {
            Xbeta <- Xdm[it, ] * beta_root
        } else {
            Xbeta <- Xdm[it, ] %*% beta_root
        }
        if (q == 1) {
            Zalpha <- Zdm[it, ] * alpha_root
        } else {
            Zalpha <- Zdm[it, ] %*% alpha_root
        }
        
        exp_Zalpha <- as.vector(exp(Zalpha))
        exp_negAXbeta <- as.vector(exp(- A[it] * Xbeta))
        exp_2Zalpha <- as.vector(exp(2 * Zalpha))
        Mn_summand[it, 1:p, 1:p] <-
            - as.numeric(Y[it] * exp_negAXbeta * A[it] * cA[it]) * (Xdm[it, ] %o% Xdm[it, ]) * avail[it]
        Mn_summand[it, 1:p, (p+1):(p+q)] <-
            - as.numeric(cA[it] * exp_Zalpha) * (Xdm[it, ] %o% Zdm[it, ]) * avail[it]
        Mn_summand[it, (p+1):(p+q), 1:p] <-
            - as.numeric(Y[it] * exp_negAXbeta * A[it] * exp_Zalpha) * (Zdm[it, ] %o% Xdm[it, ]) * avail[it]
        Mn_summand[it, (p+1):(p+q), (p+1):(p+q)] <-
            as.numeric(Y[it] * exp_negAXbeta * exp_Zalpha - 2 * exp_2Zalpha) * (Zdm[it, ] %o% Zdm[it, ]) * avail[it]
    }
    Mn <- apply(Mn_summand, c(2,3), sum) / sample_size
    Mn_inv <- solve(Mn)
    
    # Compute \Sigma_n matrix (\Sigma_n is the empirical variance of the estimating function)

    exp_Zdm_alpha <- exp(Zdm %*% alpha_root)
    exp_negAXdm_beta <- exp(- A * (Xdm %*% beta_root))
    residual <- Y * exp_negAXdm_beta - exp_Zdm_alpha
    Sigman_summand <- matrix(NA, nrow = nrow(dta), ncol = p+q)
    for (i in 1:p) {
        Sigman_summand[, i] <- residual * avail * cA * Xdm[, i]
    }
    for (i in 1:q) {
        Sigman_summand[, p+i] <- residual * avail * exp_Zdm_alpha * Zdm[, i]
    }
    
    Sigman <- matrix(0, nrow = p+q, ncol = p+q)
    for (user in 1:sample_size) {
        rows_for_this_user <- person_data_location[user]:(person_data_location[user+1] - 1)
        summand <- Sigman_summand[rows_for_this_user, ]
        summand <- colSums(summand)
        summand <- summand %o% summand
        Sigman <- Sigman + summand
    }
    Sigman <- Sigman / sample_size
    
    # Compute the asymptotic variance matrix ( this is on the scale of \sqrt{n}(\hat{\beta} - \beta) )
    
    asymp_varcov <- Mn_inv %*% Sigman %*% t(Mn_inv)
    asymp_var <- diag(asymp_varcov)
    
    # get the standard error for beta and alpha from the asymptotic variance matrix

    beta_se <- sqrt(asymp_var[1:p] / sample_size)
    alpha_se <- sqrt(asymp_var[(p+1):(p+q)] / sample_size)
    

    ############## part 4 :: estimate standard error with small sample correction ###############
    
    # construct the new "meat" in the sandwich estimator (to replace \Sigma_n)

    meat <- 0
    for (user in 1:sample_size) {
        # preparation
        rows_for_this_user <- person_data_location[user]:(person_data_location[user+1] - 1)
        A_user <- A[rows_for_this_user] # A_i1 to A_iT
        cA_user <- cA[rows_for_this_user] # centered A
        Xdm_user <- Xdm[rows_for_this_user, ] # X_i1 to X_iT
        Zdm_user <- Zdm[rows_for_this_user, ] # Z_i1 to Z_iT
        Y_user <- Y[rows_for_this_user] # Y_i1 to Y_iT
        avail_user <- avail[rows_for_this_user]
        
        # this is to make R code consistent whether X_it, Z_it contains more entries or is just 1.    
        if (p == 1) {
            Xbeta <- Xdm_user * beta_root
        } else {
            Xbeta <- Xdm_user %*% beta_root
        }
        if (q == 1) {
            Zalpha <- Zdm_user * alpha_root
        } else {
            Zalpha <- Zdm_user %*% alpha_root
        }
        
        exp_Zalpha_plus_AXbeta <- as.vector(exp(Zalpha + A_user * Xbeta))
        exp_Zalpha_minus_AXbeta <- as.vector(exp(Zalpha - A_user * Xbeta))
        exp_negAXbeta <- as.vector(exp(- A_user * Xbeta))
        
        # compute r_i
        r_i <- matrix((Y_user - exp_Zalpha_plus_AXbeta) * avail_user)
        
        # compute D_i
        D_i <- cbind( exp_negAXbeta * cA_user * Xdm_user, exp_Zalpha_minus_AXbeta * Zdm_user )
        # exp_Zalpha_minus_AXbeta * Xdm_user: multiply the vector exp_Abeta_plus_Xalpha to each column of Xdm_user
        
        # compute partial_e_i/partial_theta
        de_i <- cbind( - exp_Zalpha_plus_AXbeta * A_user * Xdm_user * avail_user,
                           - exp_Zalpha_plus_AXbeta * Zdm_user * avail_user )
        
        # compute H_i
        H_i <- de_i %*% Mn_inv %*% t(D_i) / sample_size
        
        Ii_minus_Hi_inv <- solve(diag(length(rows_for_this_user)) - H_i)
        meat <- meat + t(D_i) %*% Ii_minus_Hi_inv %*% r_i %*% t(r_i) %*% t(Ii_minus_Hi_inv) %*% D_i
    }
    meat <- meat / sample_size
    
    # calculate asymptotic variance with small sample adjustment
    # "ssa" stands for small sample adjustment

    asymp_varcov_ssa <- Mn_inv %*% meat %*% t(Mn_inv)
    asymp_var_ssa <- diag(asymp_varcov_ssa)
    
    beta_se_ssa <- sqrt(asymp_var_ssa[1:p] / sample_size)
    alpha_se_ssa <- sqrt(asymp_var_ssa[(p+1):(p+q)] / sample_size)
    
    
    ############## part 5 :: p-value with small sample correction ###############
    
    # t test (two-sided -- note the use of significance_level/2)
    
    test_stat <- beta_root / beta_se_ssa
    critical_value <- qt(1 - significance_level/2, df = n - p - q) # two-sided
    p_val <- 2 * pt(abs(test_stat), df = n - p - q, lower.tail = FALSE) # two-sided
    names(test_stat) <- names(p_val) <- Xnames
    test_result_t <- list(test_stat = test_stat,
                          critical_value = critical_value,
                          p_value = p_val)
    
    # F test (two sided, by the nature of F-test)

    test_stat <- as.numeric( t(beta_root) %*% solve(asymp_varcov_ssa[1:p, 1:p] / sample_size) %*% beta_root )
    n <- sample_size
    critical_value <- qf((n-q-p) * (1-significance_level) / (p * (n-q-1)), df1 = p, df2 = n-q-p)
    p_val <- pf(test_stat, df1 = p, df2 = n-q-p, lower.tail = FALSE)
    test_result_f <- list(test_stat = test_stat,
                         critical_value = critical_value,
                         p_value = p_val)
    
    ############## part 6 :: return the result with variable names ###############
    
    beta_hat <- as.vector(beta_root)
    names(beta_hat) <- names(beta_se) <- names(beta_se_ssa) <- Xnames
    alpha_hat <- as.vector(alpha_root)
    names(alpha_hat) <- names(alpha_se) <- names(alpha_se_ssa) <- Znames
    
    return(list(beta_hat = beta_hat, alpha_hat = alpha_hat,
                beta_se = beta_se, alpha_se = alpha_se,
                beta_se_ssa = beta_se_ssa, alpha_se_ssa = alpha_se_ssa,
                test_result_t = test_result_t,
                test_result_f = test_result_f,
                varcov = asymp_varcov / sample_size,
                varcov_ssa = asymp_varcov_ssa / sample_size,
                dims = list(p = p, q = q),
                sample_size = sample_size))
}



SARA_primary_hypothesis_1 <- function(
    dta,
    control_var,
    id_var = "userid",
    day_var = "Day",
    trt_var = "A",
    outcome_var = "Y",
    avail_var = NULL,
    prob_treatment = 1/2,
    significance_level = 0.05
) {
    ############## description ###############
    ##
    ## This function tests for primary hypothesis 1 for SARA:
    ## H0: The 4pm push notification with inspirational quote will
    ## increase the full completion of survey and/or active
    ## task the same day as compared to no inspirational quote.
    ##
    ## For more details, refer to the writeup for SARA analysis.
    
    ############## arguments ###############
    ##
    ## dta.............the data set in long format
    ## control_var...........vector of variable names used to reduce noise (Z in the model),
    ##                       could be NULL (no control covariates)
    ## id_var................variable name for subject id (to distinguish between subjects in dta)
    ## day_var...............variable name for day in study
    ## trt_var...............variable name for treatment indicator
    ## outcome_var...........variable name for outcome variable
    ## avail_var.............variable name for availability variable
    ##                       NULL (default) means always-available
    ## prob_treatment........probability of treatment (default to 1/2)
    ## significance_level....significance level for the hypothesis testing (default to 0.05)

    ############## return value ###############
    ##
    ## This function returns a list of the following components:
    ##
    ## beta..................estimated beta (marginal treatment effect)
    ## beta_se...............standard error for beta, with small sample correction
    ## test_stat.............(two-sided) t-test statsitic for testing beta = 0
    ## critical_value........(two-sided) critical value for t-test with the input significance level 
    ## p_value...............(two-sided) p-value for t-test

    # make sure dta is sorted by id_var then day_var
    dta <- dta[order(dta[, id_var], dta[, day_var]), ]
        
    result <- binary_outcome_moderated_effect(dta = dta,
                                              control_var = control_var,
                                              moderator = NULL,
                                              id_var = id_var,
                                              day_var = day_var,
                                              trt_var = trt_var,
                                              outcome_var = outcome_var,
                                              avail_var = avail_var,
                                              prob_treatment = prob_treatment,
                                              significance_level = significance_level)
    output <- list(beta = as.numeric(result$beta_hat),
                   beta_se = as.numeric(result$beta_se_ssa),
                   test_stat = as.numeric(result$test_result_t$test_stat),
                   critical_value = result$test_result_t$critical_value,
                   p_value = as.numeric(result$test_result_t$p_value),
                   alpha = as.numeric(result$alpha_hat),
                   alpha_se = as.numeric(result$alpha_se_ssa))
    return(output)
}



SARA_primary_hypothesis_2 <- function(
    dta,
    control_var,
    id_var = "userid",
    day_var = "Day",
    trt_var = "A",
    survey_completion_var,
    outcome_var = "Y",
    avail_var = NULL,
    prob_treatment = 1/2,
    significance_level = 0.05
) {
    
    ############## description ###############
    ##
    ## This function tests for primary hypothesis 2 for SARA:
    ## H0: Among individuals who complete the survey, providing a post-survey-completion
    ## meme or gif will not yield a higher rate of completion of
    ## the survey or active task the next day than not providing meme/gif
    ## reinforcement after survey completion.
    ##
    ## For more details, refer to the writeup for SARA analysis.
    
    ############## arguments ###############
    ##
    ## dta.............the data set in long format
    ## control_var...........vector of variable names used to reduce noise (Z in the model),
    ##                       could be NULL (no control covariates)
    ## id_var................variable name for subject id (to distinguish between subjects in dta)
    ## day_var...............variable name for day in study
    ## trt_var...............variable name for treatment indicator
    ## survey_completion_var......variable name for the survey completion indicator of each day (I_{it} in the writeup)
    ## outcome_var...........variable name for outcome variable
    ## avail_var.............variable name for availability variable
    ##                       NULL (default) means always-available
    ## prob_treatment........probability of treatment (default to 1/2)
    ## significance_level....significance level for the hypothesis testing (default to 0.05)
    
    ############## return value ###############
    ##
    ## This function returns a list of the following components:
    ##
    ## beta..................estimated beta (marginal treatment effect)
    ## beta_se...............standard error for beta, with small sample correction
    ## test_stat.............(two-sided) t-test statsitic for testing beta = 0
    ## critical_value........(two-sided) critical value for t-test with the input significance level 
    ## p_value...............(two-sided) p-value for t-test

    # make sure survey_completion_var is binary
    stopifnot(all(dta[, survey_completion_var] %in% c(0, 1)))
    
    # make sure dta is sorted by id_var then day_var
    dta <- dta[order(dta[, id_var], dta[, day_var]), ]
    
    # create new_dta with shifted outcome (for day t, the outcome is Y_{t+1})
    new_dta <- dta
    new_dta$survey_completion_internal <- new_dta[, survey_completion_var]
    new_dta[1:(nrow(new_dta)-1), outcome_var] <- dta[2:nrow(dta), outcome_var]
    
    # remove the last observation for each individual (since there is no Y_{t+1} for the last day)
    person_first_index <- find_change_location(dta[, id_var])
    if (length(person_first_index) != length(unique(dta[, id_var]))) {
        stop("The length of person_first_index doesn't equal the number of unique id_var's.")
    }
    person_last_index <- c(person_first_index[-1] - 1, nrow(dta))
    new_dta <- new_dta[-person_last_index, ]

    # create avail_new, which is the product of both the original availability indicator
    # and the survey_completion_var
    if (is.null(avail_var)) {
        avail <- rep(1, nrow(new_dta))
    } else {
        avail <- new_dta[, avail_var]
    }
    new_dta$avail_new <- avail * new_dta$survey_completion_internal
    
    result <- binary_outcome_moderated_effect(dta = new_dta,
                                              control_var = control_var,
                                              moderator = NULL,
                                              id_var = id_var,
                                              day_var = day_var,
                                              trt_var = trt_var,
                                              outcome_var = outcome_var,
                                              avail_var = "avail_new",
                                              prob_treatment = prob_treatment,
                                              significance_level = significance_level)
    output <- list(beta = as.numeric(result$beta_hat),
                   beta_se = as.numeric(result$beta_se_ssa),
                   test_stat = as.numeric(result$test_result_t$test_stat),
                   critical_value = result$test_result_t$critical_value,
                   p_value = as.numeric(result$test_result_t$p_value),
                   alpha = as.numeric(result$alpha_hat),
                   alpha_se = as.numeric(result$alpha_se_ssa))
    return(output)
}



SARA_exploratory_analysis <- function(
    dta,
    control_var,
    moderator,
    id_var = "userid",
    day_var = "Day",
    trt_var = "A",
    outcome_var = "Y",
    avail_var = NULL,
    prob_treatment = 1/2,
    significance_level = 0.05
) {
    ############## description ###############
    ##
    ## This function does exploratory analysis for SARA:
    ## it estimates moderated treatment effect, and test for no treatment by using an F-test.
    ##
    ## For more details, refer to the writeup for SARA analysis.
    
    ############## arguments ###############
    ##
    ## dta.............the data set in long format
    ## control_var...........vector of variable names used to reduce noise (Z in the model),
    ##                       could be NULL (no control covariates)
    ## moderator.............vector of variable names as effect modifiers (X in the model),
    ##                       could be NULL (no effect modifier)
    ## id_var................variable name for subject id (to distinguish between subjects in dta)
    ## day_var...............variable name for day in study (from 1 to max_days)
    ## trt_var...............variable name for treatment indicator
    ## outcome_var...........variable name for outcome variable
    ## avail_var.............variable name for availability variable
    ##                       NULL (default) means always-available
    ## prob_treatment........probability of treatment (default to 1/2)
    ## significance_level....significance level for the hypothesis testing (default to 0.05)
    
    ############## return value ###############
    ##
    ## This function returns a list of the following components:
    ##
    ## beta..................estimated beta (moderated treatment effect)
    ## beta_se...............standard error for beta, with small sample correction
    ## test_stat_t.............(two-sided) t-test statsitic for testing beta = 0
    ## critical_value_t........(two-sided) critical value for t-test with the input significance level 
    ## p_value_t...............(two-sided) p-value for t-test
    ## test_stat_f.............F-test statsitic for testing all beta's = 0
    ## critical_value_f........critical value for F-test with the input significance level 
    ## p_value_f...............p-value for F-test
    
    ## Note: all tests are using standard error estimates with small sample correction
    
    
    # make sure dta is sorted by id_var then day_var
    dta <- dta[order(dta[, id_var], dta[, day_var]), ]
    
    result <- binary_outcome_moderated_effect(dta = dta,
                                              control_var = control_var,
                                              moderator = moderator,
                                              id_var = id_var,
                                              trt_var = trt_var,
                                              outcome_var = outcome_var,
                                              avail_var = avail_var,
                                              prob_treatment = prob_treatment,
                                              significance_level = significance_level)
    output <- list(beta = as.numeric(result$beta_hat),
                   beta_se = as.numeric(result$beta_se_ssa),
                   test_stat_t = as.numeric(result$test_result_t$test_stat),
                   critical_value_t = result$test_result_t$critical_value,
                   p_value_t = as.numeric(result$test_result_t$p_value),
                   test_stat_f = result$test_result_f$test_stat,
                   critical_value_f = result$test_result_f$critical_value,
                   p_value_f = result$test_result_f$p_value,
                   alpha = as.numeric(result$alpha_hat),
                   alpha_se = as.numeric(result$alpha_se_ssa))
    return(output)
}


## In a future update, it may be desirable to merge SARA_exploratory_analysis_general_F_test()
## with SARA_exploratory_analysis().
SARA_exploratory_analysis_general_F_test <- function(
    dta,
    control_var,
    moderator,
    id_var = "userid",
    day_var = "Day",
    trt_var = "A",
    outcome_var = "Y",
    avail_var = NULL,
    prob_treatment = 1/2,
    significance_level = 0.05,
    F_test_L,
    F_test_c = NULL
) {
    ############## description ###############
    ##
    ## This function does exploratory analysis for SARA:
    ## it estimates moderated treatment effect, and test for no treatment by using an F-test.
    ##
    ## For more details, refer to the writeup for SARA analysis.
    
    ############## arguments ###############
    ##
    ## dta.............the data set in long format
    ## control_var...........vector of variable names used to reduce noise (Z in the model),
    ##                       could be NULL (no control covariates)
    ## moderator.............vector of variable names as effect modifiers (X in the model),
    ##                       could be NULL (no effect modifier)
    ## id_var................variable name for subject id (to distinguish between subjects in dta)
    ## day_var...............variable name for day in study (from 1 to max_days)
    ## trt_var...............variable name for treatment indicator
    ## outcome_var...........variable name for outcome variable
    ## avail_var.............variable name for availability variable
    ##                       NULL (default) means always-available
    ## prob_treatment........probability of treatment (default to 1/2)
    ## significance_level....significance level for the hypothesis testing (default to 0.05)
    ## F_test_L, F_test_c....test for H_0: F_test_L %*% beta_hat = F_test_c,
    ##                       where dim(beta) = p * 1, dim(F_test_L) = p1 * p, dim(F_test_c) = p1 * 1.
    ##                       If F_test_L is passed in as a vector, it will be treated as a row vector.
    ##                       If F_test_c is unspecified, it will be default to 0.
    
    ############## return value ###############
    ##
    ## This function returns a list of the following components:
    ##
    ## beta..................estimated beta (moderated treatment effect)
    ## beta_se...............standard error for beta, with small sample correction
    ## test_stat_t.............(two-sided) t-test statsitic for testing beta = 0
    ## critical_value_t........(two-sided) critical value for t-test with the input significance level 
    ## p_value_t...............(two-sided) p-value for t-test
    ## test_stat_f.............F-test statsitic for testing F_test_L %*% beta_hat = F_test_c
    ## critical_value_f........critical value for F-test with the input significance level 
    ## p_value_f...............p-value for F-test
    
    ## Note: all tests are using standard error estimates with small sample correction
    
    
    # make sure dta is sorted by id_var then day_var
    dta <- dta[order(dta[, id_var], dta[, day_var]), ]
    
    result <- binary_outcome_moderated_effect(dta = dta,
                                              control_var = control_var,
                                              moderator = moderator,
                                              id_var = id_var,
                                              trt_var = trt_var,
                                              outcome_var = outcome_var,
                                              avail_var = avail_var,
                                              prob_treatment = prob_treatment,
                                              significance_level = significance_level)

    n <- result$sample_size
    q <- length(result$alpha_hat)
    
    beta_hat <- result$beta_hat
    p <- length(beta_hat)
    beta_hat <- matrix(beta_hat, ncol = 1)
    varcov_beta_hat <- result$varcov_ssa[1:p, 1:p]
    
    ## general F test for F_test_L %*% beta_hat = F_test_c ##
    if (is.vector(F_test_L)) {
        F_test_L <- matrix(F_test_L, nrow = 1)
    }
    p1 <- dim(F_test_L)[1]
    if (is.null(F_test_c)) {
        F_test_c <- matrix(rep(0, p1), ncol = 1)
    }
    if (dim(F_test_L)[1] != dim(F_test_c)[1]) {
        stop("The dimensions of F_test_L and F_test_c are not coherent.")
    }
    
    tmp <- F_test_L %*% beta_hat - F_test_c
    test_stat_f <- (t(tmp) %*% solve(F_test_L %*% varcov_beta_hat %*% t(F_test_L)) %*% tmp)
    # test statistic is computed in the same manner as in Liao et al. (2016)
    test_stat_f <- as.numeric(test_stat_f)
    critical_value_f <- qf((n-q-p1) * (1-significance_level) / (p1 * (n-q-1)), df1 = p1, df2 = n-q-p)
    # critical value is computed as in Section 5 of Boruvka et al. (2018)
    p_value_f <- pf(test_stat_f, df1 = p1, df2 = n-q-p, lower.tail = FALSE)
    
    
    output <- list(beta = as.numeric(result$beta_hat),
                   beta_se = as.numeric(result$beta_se_ssa),
                   test_stat_t = as.numeric(result$test_result_t$test_stat),
                   critical_value_t = result$test_result_t$critical_value,
                   p_value_t = as.numeric(result$test_result_t$p_value),
                   test_stat_f = test_stat_f,
                   critical_value_f = critical_value_f,
                   p_value_f = p_value_f,
                   alpha = as.numeric(result$alpha_hat),
                   alpha_se = as.numeric(result$alpha_se_ssa))
    return(output)
}



##### example to use the function #####

if (0) {
    
    dta <- readRDS("example_dataset.RDS")
    
    ### construct control covariates and moderators ###
    
    # previous day's outcome
    dta$Y_lag1 <- c(0, dta$Y[1:(nrow(dta)-1)])
    dta$Y_lag1[dta$Day == 1] <- 0 # fill in 0 for Y_lag1 on Day 1
    
    # previous day's at_tapcount
    dta$at_tapcount_lag1 <- c(0, dta$at_tapcount[1:(nrow(dta)-1)])
    dta$at_tapcount_lag1[is.na(dta$at_tapcount_lag1)] <- 0 # fill in 0 for at_tapcount_lag1 = NA
    # Note: this fill-in 0's is just to make the code run.
    # In practice missing data should be handled more thoughtfully.
    
    ### try out the three analysis functions ###
    
    # primary hypothesis 1
    SARA_primary_hypothesis_1(dta, control_var = c("Y_lag1", "at_tapcount_lag1"))
    
    # primary hypothesis 2
    SARA_primary_hypothesis_2(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), survey_completion_var = "Y")
    
    # exploratory analysis
    SARA_exploratory_analysis(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1")
    
    # this will give the same F-test result as SARA_exploratory_analysis()
    SARA_exploratory_analysis_general_F_test(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", F_test_L = diag(2))
    
    SARA_exploratory_analysis_general_F_test(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", F_test_L = rep(1, 2))
    
    
    ### create fake availability indicator, and try the three analysis functions with availability ###
    set.seed(123)
    dta2 <- dta
    dta2$avail <- rbinom(nrow(dta2), 1, 0.2)
    dta2$A[dta2$avail == 0] <- NA
    SARA_primary_hypothesis_1(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), avail_var = "avail")
    SARA_primary_hypothesis_2(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), survey_completion_var = "Y", avail_var = "avail")
    SARA_exploratory_analysis(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", avail_var = "avail")
    
}


if (0) {
    # output of the above example
    # Version: 2019/2/5
    
    # All the p-values for t-tests are doubled compared to the previous version.
    # This is as expected, because we changed from one-sided to two-sided test.
    
    
    >     ### try out the three analysis functions ###
        >     
        >     # primary hypothesis 1
        >     SARA_primary_hypothesis_1(dta, control_var = c("Y_lag1", "at_tapcount_lag1"))
    $beta
    [1] 0.1761973
    
    $beta_se
    [1] 0.01926731
    
    $test_stat
    [1] 9.144882
    
    $critical_value
    [1] 1.984984
    
    $p_value
    [1] 1.022584e-14
    
    $alpha
    [1] -0.4286552699  0.0001338947  0.0022651338
    
    $alpha_se
    [1] 0.0271394442 0.0292520053 0.0003041147
    
    >     
        >     # primary hypothesis 2
        >     SARA_primary_hypothesis_2(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), survey_completion_var = "Y")
    $beta
    [1] 0.006871496
    
    $beta_se
    [1] 0.01939516
    
    $test_stat
    [1] 0.3542892
    
    $critical_value
    [1] 1.984984
    
    $p_value
    [1] 0.7238992
    
    $alpha
    [1] -0.1914996030 -0.0078097155  0.0001918152
    
    $alpha_se
    [1] 0.0287537133 0.0294240517 0.0003142004
    
    >     
        > # exploratory analysis
        >     SARA_exploratory_analysis(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1")
    $beta
    Intercept     Y_lag1 
    0.3493801 -0.2138751 
    
    $beta_se
    Intercept     Y_lag1 
    0.05310572 0.05948923 
    
    $test_stat_t
    [1]  6.578955 -3.595191
    
    $critical_value_t
    [1] 1.985251
    
    $p_value_t
    [1] 2.571782e-09 5.163757e-04
    
    $test_stat_f
    [1] 95.53464
    
    $critical_value_f
    [1] 0.6631817
    
    $p_value_f
    [1] 1.81756e-23
    
    $alpha
    [1] -0.522625830  0.121815023  0.002169604
    
    $alpha_se
    [1] 0.0449813807 0.0515054456 0.0003145783
    
    > # this will give the same F-test result as SARA_exploratory_analysis()
        >     SARA_exploratory_analysis_general_F_test(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", F_test_L = diag(2))
    $beta
    Intercept     Y_lag1 
    0.3493801 -0.2138751 
    
    $beta_se
    Intercept     Y_lag1 
    0.05310572 0.05948923 
    
    $test_stat_t
    [1]  6.578955 -3.595191
    
    $critical_value_t
    [1] 1.985251
    
    $p_value_t
    [1] 2.571782e-09 5.163757e-04
    
    $test_stat_f
    [1] 95.53464
    
    $critical_value_f
    [1] 0.6631817
    
    $p_value_f
    [1] 1.81756e-23
    
    $alpha
    [1] -0.522625830  0.121815023  0.002169604
    
    $alpha_se
    [1] 0.0449813807 0.0515054456 0.0003145783
    
    > SARA_exploratory_analysis_general_F_test(dta, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", F_test_L = rep(1, 2))
    $beta
    Intercept     Y_lag1 
    0.3493801 -0.2138751 
    
    $beta_se
    Intercept     Y_lag1 
    0.05310572 0.05948923 
    
    $test_stat_t
    [1]  6.578955 -3.595191
    
    $critical_value_t
    [1] 1.985251
    
    $p_value_t
    [1] 2.571782e-09 5.163757e-04
    
    $test_stat_f
    [1] 40.83885
    
    $critical_value_f
    [1] 5.186928
    
    $p_value_f
    [1] 6.113323e-09
    
    $alpha
    [1] -0.522625830  0.121815023  0.002169604
    
    $alpha_se
    [1] 0.0449813807 0.0515054456 0.0003145783
    
    >     
        >     
        >     ### create fake availability indicator, and try the three analysis functions with availability ###
        >     set.seed(123)
    >     dta2 <- dta
    >     dta2$avail <- rbinom(nrow(dta2), 1, 0.2)
    >     dta2$A[dta2$avail == 0] <- NA
    >     SARA_primary_hypothesis_1(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), avail_var = "avail")
    $beta
    [1] 0.08584806
    
    $beta_se
    [1] 0.03993013
    
    $test_stat
    [1] 2.149957
    
    $critical_value
    [1] 1.984984
    
    $p_value
    [1] 0.03407131
    
    $alpha
    [1] -0.32417513 -0.03184334  0.00195437
    
    $alpha_se
    [1] 0.0563985798 0.0640324410 0.0006506912
    
    >     SARA_primary_hypothesis_2(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), survey_completion_var = "Y", avail_var = "avail")
    $beta
    [1] 0.02120382
    
    $beta_se
    [1] 0.04106978
    
    $test_stat
    [1] 0.5162875
    
    $critical_value
    [1] 1.984984
    
    $p_value
    [1] 0.6068408
    
    $alpha
    [1] -0.2131429183  0.0033599799  0.0000873171
    
    $alpha_se
    [1] 0.0485193353 0.0605234082 0.0008457411
    
    >     SARA_exploratory_analysis(dta2, control_var = c("Y_lag1", "at_tapcount_lag1"), moderator = "Y_lag1", avail_var = "avail")
    $beta
    Intercept      Y_lag1 
    0.13959347 -0.06764016 
    
    $beta_se
    Intercept    Y_lag1 
    0.1104629 0.1155651 
    
    $test_stat_t
    [1]  1.2637142 -0.5852992
    
    $critical_value_t
    [1] 1.985251
    
    $p_value_t
    [1] 0.2094249 0.5597343
    
    $test_stat_f
    [1] 4.588463
    
    $critical_value_f
    [1] 0.6631817
    
    $p_value_f
    [1] 0.01252342
    
    $alpha
    [1] -0.352447929  0.006808953  0.001907070
    
    $alpha_se
    [1] 0.0873681644 0.1024315444 0.0006620606
}
