#' Stratify a Population Data Frame
#'
#' This function takes as input any data frame that you want to stratify into clusters. Typically, the goal of such stratification is sampling for generalizability. This function, and the others in this package, are designed to mimic the website https://www.thegeneralizer.org/.
#'
#' @param data The R object containing your population data frame
#' @param guided logical; defaults to TRUE. Whether the function should be guided (ask questions and behave interactively throughout) or not. If set to FALSE, must provide values for other arguments below
#' @param n_strata defaults to NULL. If guided is set to FALSE, must provide a number of strata to cluster population into
#' @param variables defaults to NULL. If guided is set to FALSE, must provide a character vector of the names of stratifying variables (from population data frame)
#' @param idnum defaults to NULL. If guided is set to FALSE, must provide a character vector of the name of the ID variable (from population data frame)
#' @return The function returns a list of class "generalizer_output" that can be provided as input to \code{recruit()}. More information on the components of this list can be found above under "Details."
#' @details The list contains 11 components: \code{x2}, \code{solution}, \code{n_strata}, \code{recruitment_lists}, \code{population_summary_stats2}, \code{summary_stats}, \code{summary_stats2}, \code{heat_data}, \code{heat_plot_final}, \code{idnum}, and \code{variables}.
#'
#' \itemize{
#' \item{\code{x2}: }{a tibble with number of rows equal to the number of rows in the inference population (\code{data}) and number of columns equal to the number of stratifying variables (dummy-coded if applicable) plus the ID column (\code{idnum}) and a column representing stratum membership, \code{clusterID}}
#' }
#' @export
#' @importFrom graphics par
#' @importFrom stats mahalanobis median na.omit sd var
#' @importFrom utils menu select.list
#' @importFrom crayon %+% blue bold
#' @importFrom janitor clean_names
#' @importFrom ggplot2 ggplot aes geom_bar xlab labs geom_histogram geom_text geom_label geom_hline scale_fill_gradientn scale_x_discrete expand_limits geom_tile element_blank element_text theme
#' @importFrom ggthemes theme_base
#' @importFrom tidyr pivot_longer unite_
#' @importFrom dplyr count arrange filter mutate summarise_all summarize_if left_join group_by select select_if all_of mutate_all case_when bind_rows bind_cols distinct everything
#' @importFrom tibble tibble_row add_row tibble
#' @importFrom ClusterR KMeans_rcpp
#' @importFrom purrr map_dbl map_df negate
#' @importFrom magrittr %>%
#' @importFrom cluster daisy
#' @importFrom stringr str_sub
#' @importFrom grid unit
#' @importFrom tidyselect contains
#' @references
#' Tipton, E. (2014). Stratified sampling using cluster analysis: A sample selection strategy for improved generalizations from experiments. *Evaluation Review*, *37*(2), 109-139.
#'
#' Tipton, E. (2014). How generalizable is your experiment? An index for comparing experimental samples and populations. *Journal of Educational and Behavioral Statistics*, *39*(6), 478-501.
#' @examples
#' \donttest{
#' \dontrun{
#' # To get sample data; must first be installed using install_github("katiecoburn/generalizeRdata")
#' library(generalizeRdata)
#'
#' # Guided:
#' stratify(ipeds)
#'
#' # Not guided:
#' stratify(ipeds, guided = FALSE, n_strata = 4,
#'    variables = c("pct_female", "pct_white"), idnum = "unitid")
#' }
#' }
#' @md

stratify <- function(data, guided = TRUE, n_strata = NULL, variables = NULL,
                     idnum = NULL){

  skim_variable <- skim_type <- variable <- NULL
  type <- clusterID <- n <- mn <- deviation <- NULL

  blankMsg <- sprintf("\r%s\r", paste(rep(" ", getOption("width") - 1L), collapse = " "));

  if(guided == TRUE){

    ## Check ##
    if(!is.null(n_strata) | !is.null(variables) | !is.null(idnum)){
      stop(simpleError("Don't specify n_strata, variables, or idnum as arguments if you are running the guided version of this function."))
    }

    cat(bold("If you want to store your results, make sure you assign \nthis function to an object.\n\n"))
    cat("Your chosen inference population is the '",
        deparse(substitute(data)), "' dataset.", sep = "")

    cat("\n")
    cat("\n")

    idnum <- readline(prompt = "Enter the name of the ID Variable in your dataset: ")

    ## Check ##
    if(!idnum %in% names(data))
    stop(simpleError("We could not find that variable. Please make sure your \ndataset contains an ID variable."))

    cat("\nIf you want to adjust or restrict your inference population \n(e.g., if you are interested in only one location, etc.), \nmake sure that you have altered the data frame appropriately. \nIf you need to alter your data frame, you can exit this \nfunction, use " %+% blue$bold("dplyr::filter()") %+% ", and \nreturn.\n")

    if(menu(choices = c("Yes", "No"), title = cat("\nDo you wish to proceed?")) == 1){

    }else{
      stop(simpleError(blankMsg))
    }

    id <- data %>% select(all_of(idnum))
    data <- data %>% select(-all_of(idnum))

    variables_are_correct <- 0

    while(variables_are_correct != 1){
      cat("\nYou're now ready to select your stratification variables. \nThe following are the variables available in your dataset.")

      names <- names(data)
      variables <- select.list(choices = names,
                       title = cat("\nWhich key variables do you think may explain variation \nin your treatment effect?",
                                   "Typically, studies include \nup to 10 variables for stratification.\n"),
                       graphics = FALSE, multiple = TRUE)

      if(length(variables) >= 1){
        data_subset <- data %>%
          select(all_of(variables))
      }else{
        ## Check ##
        stop("You have to select some stratifying variables.")
      }

      var_overview <- skimr::skim(data_subset) %>% tibble() %>%
        distinct(skim_variable, skim_type) %>%
        mutate(variable = skim_variable, type = skim_type) %>%
        select(variable, type) %>%
        data.frame()

      colnames(var_overview) <- c("Variable", "Type")

      cat("\nYou have selected the following stratifying variables: \n")
      cat(paste(blue$bold(colnames(data_subset)), collapse = ", "), ".\n\n", sep = "")
      print(var_overview, row.names = FALSE)

      if(menu(choices = c("Yes", "No"), title = cat("\nIs this correct?")) == 1){

        variables_are_correct <- 1

      }else{

        variables_are_correct <- 0

      }
    }

    cat_data <- data_subset %>%
      select_if(is.factor)
    cat_data_vars <- names(cat_data)
    if(dim(cat_data)[2] >= 1){
      cat_data_plot <- data.frame(cat_data) %>%
        na.omit()
      cat("Please review the descriptive statistics of your \ncategorical variables (factors). Note that these will \nautomatically be converted to dummy variables for analysis.\n")
      for(i in 1:(ncol(cat_data_plot))){
        var_name <- cat_data_vars[i]
        cat("\nNumber of Observations in Levels of Factor ", paste(blue$bold(var_name)), ":\n", sep = "")
        print(table(cat_data_plot[,i]))
        barfig <- ggplot(data = cat_data_plot, aes(x = cat_data_plot[,i])) +
          geom_bar() +
          theme_base() +
          xlab(var_name) +
          labs(title = paste("Bar Chart of", var_name))
        print(barfig)
        cat("\n")
        par(ask = TRUE)
      }
    }

    cont_data <- data_subset %>%
      select_if(negate(is.factor))
    cont_data_vars <- names(cont_data)
    if(dim(cont_data)[2] >= 1){
      sumstats <- cont_data %>%
        na.omit() %>%
        map_df(function(x){
          tibble(min = min(x), pct50 = median(x), max = max(x), mean = mean(x), sd = sd(x))
        }) %>%
        mutate_all(round, digits = 3) %>%
        mutate(variable = cont_data_vars) %>%
        select(variable, everything()) %>%
        clean_names() %>%
        data.frame()

      cat("Please review the descriptive statistics of your \ncontinuous variables.\n\n")
      print(sumstats, row.names = FALSE)
      for(i in 1:ncol(cont_data)){
        cont_data_plot <- cont_data %>% na.omit() %>% data.frame()
        suppressWarnings(
          suppressMessages(
            hist <- ggplot(data = cont_data_plot, aes(x = cont_data_plot[,i])) +
              geom_histogram(bins = 30) +
              theme_base() +
              xlab(cont_data_vars[i]) +
              labs(title = paste("Histogram of", cont_data_vars[i]))
          )
        )
        print(hist)
        par(ask = TRUE)
      }
    }
    par(ask = FALSE)

    if(dim(cat_data)[2] >= 1){
      cat_data <- fastDummies::dummy_cols(cat_data, remove_first_dummy = TRUE) %>% select_if(negate(is.factor))
      data_full <- cbind(cat_data, cont_data, id) %>%
        na.omit()
      id <- data_full %>% select(idnum)
      data_full <- data_full %>% select(-idnum)
    }else{
      data_full <- cbind(cont_data, id) %>%
        na.omit()
      id <- data_full %>% select(idnum)
      data_full <- data_full %>% select(-idnum)
    }

    cat("Stratification will help you develop a recruitment plan so \nthat your study will result in an unbiased estimate of the \n" %+% bold("average treatment effect (ATE)") %+% ". Without using strata, \nit is easy to end up with a sample that is very different \nfrom your inference population. \n\nGeneralization works best when strata are " %+% bold("homogeneous") %+% ". \nThat means units within each stratum are almost identical \nin terms of relevant variables.\n\n")

    satisfied <- 0

    while(satisfied != 1){
      cat("Enter a number of strata to divide your population into. \nTypically, the " %+% bold("more strata") %+% ", the better; with fewer strata, \nunits in each stratum are no longer identical. However, \nincreasing the number of strata uses more resources, because \nyou must sample a given number of units from each stratum. \n\nTry a few #s and choose the 'best' one for you.")

      n_strata <- suppressWarnings(as.numeric(readline(prompt = "# of strata: ")))

      ## Catch ##
      if(is.na(n_strata)){
        stop(simpleError("The number of strata must be one number."))
      }

      ## Catch ##
      if(n_strata <= 1){
        stop(simpleError("The number of strata must be a positive number greater than one."))
      }

      if(n_strata%%1==0){
        n_strata <- round(n_strata)
      }

      cat("This might take a little while. Please bear with us.")

      suppressWarnings(distance <- daisy(data_full, metric = "gower"))
      cat("\n1: Calculated distance matrix.")
      solution <- KMeans_rcpp(as.matrix(distance), clusters = n_strata, verbose = TRUE)

      x2 <- data.frame(id, data_full, clusterID = solution$clusters)
      recruitment_lists <- list(NULL)

      for(i in 1:n_strata){
        dat3 <- x2 %>%
          dplyr::filter(clusterID == i)
        idvar <- dat3 %>% select(all_of(idnum))
        dat4 <- dat3 %>% select(-c(all_of(idnum), clusterID)) %>%
          mutate_all(as.numeric)

        mu <- dat4 %>% map_dbl(mean)
        v <- var(dat4)
        a <- diag(v)

        if(any(a == 0)){ a[which(a == 0)] <- 0.00000001 }
        cov.dat <- diag(a)
        ma.s <- mahalanobis(dat4, mu, cov.dat)
        final_dat4 <- data.frame(idvar, dat4, distance = ma.s, clusterID = dat3$clusterID) %>% tibble()
        recruitment_lists[[i]] <- final_dat4 %>% # Produces a list of data frames, one per stratum, sorted by
          # distance (so the top N schools in each data frame are the "best," etc.)
          arrange(distance) %>%
          mutate(rank = seq.int(nrow(final_dat4))) %>%
          select(rank, all_of(idnum))
  }

      cat(blue$bold("Congratulations, you have successfully grouped your data into", n_strata, "strata!\n"))

      readline(prompt = "Press [enter] to view the results")

      cat("\nYou have specified ")
      cat(bold(n_strata))
      cat(" strata, which explain ")
      cat(paste(bold(100 * round(solution$between.SS_DIV_total.SS, 4), "%", sep = "")))
      cat(" of the total \nvariation in the population.")

      cat("\n\nThe following table presents the mean and standard deviation \n(mean / sd) of each stratifying variable for each stratum. \nThe bottom row, 'Population,' presents the average values for \nthe entire inference population. The last column, 'n,' lists the \ntotal number of units in the inference population that fall \nwithin each stratum.\n\n")

      # x2 <- data.frame(id, data_full, clusterID = solution$clusters) %>% tibble()
      x3 <- data.frame(data_full, clusterID = solution$clusters) %>% tibble()

      population_summary_stats2 <- x3 %>% select(-c(clusterID)) %>%
        summarise_all(list(mean, sd)) %>%
        mutate_all(round, digits = 3)

      population_summary_stats <- population_summary_stats2 %>%
        names() %>% str_sub(end = -5) %>% unique() %>%
        lapply(function(x){
          unite_(population_summary_stats2, x, grep(x, names(population_summary_stats2), value = TRUE),
                 sep = ' / ', remove = TRUE) %>% select(x)
        }) %>%
        bind_cols()

      summary_stats <- x3 %>%
        group_by(clusterID) %>%
        summarize_if(is.numeric, mean) %>%
        left_join((x3 %>% group_by(clusterID) %>% summarize_if(is.numeric, sd)),
                  by = "clusterID", suffix = c("_fn1", "_fn2")) %>%
        mutate_all(round, digits = 3)

      summary_stats2 <- summary_stats %>%
        select(-clusterID) %>%
        names() %>%
        str_sub(end = -5) %>%
        unique() %>%
        lapply(function(x){
          unite_(summary_stats, x, grep(x, names(summary_stats), value = TRUE),
                                  sep = ' / ', remove = TRUE) %>% select(x)
          }) %>%
        bind_cols() %>% mutate(clusterID = summary_stats$clusterID) %>%
        select(clusterID, everything()) %>%
        left_join((x3 %>% group_by(clusterID) %>% count()), by = "clusterID") %>%
        mutate(clusterID = as.character(clusterID)) %>%
        add_row(tibble_row(clusterID = "Population", population_summary_stats, n = dim(x2)[1])) %>%
        data.frame()

      print(summary_stats2)

      simtab_m <- population_summary_stats2 %>%
        select(contains("fn1"))
      names(simtab_m) <- names(simtab_m) %>% str_sub(end = -5)
      sd_tab <- summary_stats %>%
        select(contains("fn2")) %>%
        add_row(tibble_row((population_summary_stats2 %>% select(contains("fn2")))))
      names(sd_tab) <- names(sd_tab) %>% str_sub(end = -5)
      sd_tab <- sd_tab %>%
        mutate(clusterID = summary_stats2$clusterID) %>%
        pivot_longer(-clusterID, names_to = "variable", values_to = "sd")
      mean_tab <- summary_stats %>%
        select(contains("fn1")) %>%
        add_row(tibble_row((population_summary_stats2 %>% select(contains("fn1")))))
      names(mean_tab) <- names(mean_tab) %>% str_sub(end = -5)
      mean_tab <- mean_tab %>%
        mutate(clusterID = summary_stats2$clusterID) %>%
        pivot_longer(-clusterID, names_to = "variable", values_to = "mn")
      counts_tab <- summary_stats2 %>%
        select(clusterID, n)

      heat_data <- left_join(mean_tab, sd_tab, by = c("clusterID", "variable")) %>%
        left_join(counts_tab, by = "clusterID")
      temporary_df <- data.frame(variable = unique(heat_data$variable),
                        population_mean = (heat_data %>% filter(clusterID == "Population") %>% select(mn))) %>%
        mutate(population_mean = mn) %>%
        select(-mn)
      heat_data <- heat_data %>% left_join(temporary_df, by = "variable") %>%
        mutate(deviation = case_when((mn - population_mean)/population_mean >= 0.7 ~ 0.7,
                                     (mn - population_mean)/population_mean <= -0.7 ~ -0.7,
                                     TRUE ~ (mn - population_mean)/population_mean))
      cluster_labels <- "Population"
      for(i in 2:(n_strata + 1)){
        cluster_labels[i] <- paste("Stratum", (i - 1))
      }

      heat_plot_final <- ggplot(data = heat_data) +
        geom_tile(aes(x = clusterID, y = variable, fill = deviation), width = 0.95) +
        geom_text(aes(x = clusterID, y = ((ncol(summary_stats) + 1)/2 - 0.15),
                      label = paste(n, "\nunits")), size = 3.4) +
        geom_label(aes(x = clusterID, y = variable,
                       label = paste0(round(mn, 1), "\n(", round(sd, 1), ")")),
                   colour = "black", alpha = 0.7,
                   size = ifelse((length(levels(heat_data$variable %>% factor())) + 1) > 7, 2, 3.5)) +
        geom_hline(yintercept = seq(1.5, (ncol(summary_stats) - 1), 1),
                   linetype = "dotted",
                   colour = "white") +
        scale_fill_gradientn(name = NULL, breaks=c(-0.5, 0, 0.5),
                             labels = c("50% \nBelow Mean",
                                        "Population\nMean",
                                        "50% \nAbove Mean"),
                             colours = c("#990000", "#CC0000",
                                         "white", "#3D85C6",
                                         "#0B5294"),
                             limits = c(-0.7, 0.7)) +
        scale_x_discrete(position = "top", expand = c(0, 0), labels = c(cluster_labels[-1], "Population")) +
        expand_limits(y = c(0, (ncol(summary_stats) + 1)/2 + 0.1)) +
        labs(y = NULL, x = NULL) +
        theme(panel.background = element_blank(),
              axis.ticks = element_blank(),
              axis.text = element_text(size = 10, colour = "grey15"),
              legend.key.height = unit(1, "cm"),
              legend.text = element_text(size = 10),
              legend.position = "right")


      readline(prompt = "Press [enter] to continue:")

      print(heat_plot_final)

      if(menu(choices = c("Yes", "No"), title = cat("\nWould you like to go back and specify a different number of strata?")) == 2){

        satisfied <- 1

      }else{

        satisfied <- 0

      }

    }

  }else{
    par(ask = FALSE)

    ###### Checks Begin Here ######

    if(is.null(n_strata) | is.null(variables) | is.null(idnum)){
      stop(simpleError("You must specify n_strata, variables, and idnum as arguments if you are running the non-guided version of this function."))
    }

    if(!is.numeric(n_strata)){
      stop(simpleError("The number of strata must be a number."))
    }

    if((length(n_strata) > 1)){
      stop(simpleError("Only specify one number of strata."))
    }

    if(n_strata <= 1){
      stop(simpleError("The number of strata must be a positive number greater than 1."))
    }

    if(n_strata%%1==0){
      n_strata <- round(n_strata)
    }

    if(!is.character(variables) | (anyNA(match(variables, names(data))))){
      stop(simpleError("You must provide a character vector consisting of the names of stratifying variables in your inference population."))
    }

    if(!is.character(idnum) | is.na(match(idnum, names(data)))){
      stop(simpleError("idnum should be the name of the identifying variable in your inference population -- e.x.: 'id'."))
    }

    ###### Checks End Here ######

    # This is where all the non-guided stuff goes

    cat("Your chosen inference population is the '",
        deparse(substitute(data)), "' dataset.\n", sep = "")
    cat("\n")

    id <- data %>% select(all_of(idnum))
    data <- data %>% select(-all_of(idnum))

    data <- data %>%
      select(all_of(variables))

    cat_data <- data %>%
      select_if(is.factor)
    cat_data_vars <- names(cat_data)
    if(dim(cat_data)[2] >= 1){
      cat_data_plot <- data.frame(cat_data) %>%
        na.omit()
      cat("Please review the descriptive statistics of your \n" %+% bold("categorical variables (factors).") %+% "Note that these will \nautomatically be converted to dummy variables for analysis.\n")
      for(i in 1:(ncol(cat_data_plot))){
        var_name <- cat_data_vars[i]
        cat("\nNumber of Observations in Levels of Factor ", paste(blue$bold(var_name)), ":\n", sep = "")
        print(table(cat_data_plot[,i]))
        barfig <- ggplot(data = cat_data_plot, aes(x = cat_data_plot[,i])) +
          geom_bar() +
          theme_base() +
          xlab(var_name) +
          labs(title = paste("Bar Chart of", var_name))
        print(barfig)
        cat("\n")
      }
    }

    cont_data <- data %>%
      select_if(negate(is.factor))
    cont_data_vars <- names(cont_data)
    if(dim(cont_data)[2] >= 1){
      sumstats <- cont_data %>%
        na.omit() %>%
        map_df(function(x){
          tibble(min = min(x), pct50 = median(x), max = max(x), mean = mean(x), sd = sd(x))
        }) %>%
        mutate_all(round, digits = 3) %>%
        mutate(variable = cont_data_vars) %>%
        select(variable, everything()) %>%
        clean_names() %>%
        data.frame()

      cat("Please review the descriptive statistics of your \n" %+% bold("continuous variables") %+% ".\n\n")
      print(sumstats, row.names = FALSE)
      for(i in 1:ncol(cont_data)){
        cont_data_plot <- cont_data %>% data.frame()
        suppressWarnings(
          suppressMessages(
            hist <- ggplot(data = cont_data_plot, aes(x = cont_data_plot[,i])) +
              geom_histogram(bins = 30) +
              theme_base() +
              xlab(cont_data_vars[i]) +
              labs(title = paste("Histogram of", cont_data_vars[i]))
          )
        )
        print(hist)
      }
    }

    cat("\n\nThis might take a little while. Please bear with us.")

    if(dim(cat_data)[2] >= 1){
      cat_data <- fastDummies::dummy_cols(cat_data, remove_first_dummy = TRUE) %>%
        select_if(negate(is.factor))
      data_full <- cbind(cat_data, cont_data, id) %>%
        na.omit()
      id <- data_full %>% select(idnum)
      data_full <- data_full %>% select(-idnum)
    }else{
      data_full <- cbind(cont_data, id) %>%
        na.omit()
      id <- data_full %>% select(idnum)
      data_full <- data_full %>% select(-idnum)
    }

    suppressWarnings(distance <- daisy(data_full, metric = "gower"))
    cat("\n1: Calculated distance matrix.")
    solution <- KMeans_rcpp(as.matrix(distance), clusters = n_strata, verbose = TRUE)

    x2 <- data.frame(id, data_full, clusterID = solution$clusters)
    recruitment_lists <- list(NULL)

    for(i in 1:n_strata){
      dat3 <- x2 %>%
        dplyr::filter(clusterID == i)
      idvar <- dat3 %>% select(all_of(idnum))
      dat4 <- dat3 %>% select(-c(all_of(idnum), clusterID)) %>%
        mutate_all(as.numeric)

      mu <- dat4 %>% map_dbl(mean)
      v <- var(dat4)
      a <- diag(v)

      if(any(a == 0)){ a[which(a == 0)] <- 0.00000001 }
      cov.dat <- diag(a)
      ma.s <- mahalanobis(dat4, mu, cov.dat)
      final_dat4 <- data.frame(idvar, dat4, distance = ma.s, clusterID = dat3$clusterID) %>% tibble()
      recruitment_lists[[i]] <- final_dat4 %>% # Produces a list of data frames, one per stratum, sorted by
        # distance (so the top N schools in each data frame are the "best," etc.)
        arrange(distance) %>%
        mutate(rank = seq.int(nrow(final_dat4))) %>%
        select(rank, all_of(idnum))
    }

    cat(blue$bold("Congratulations, you have successfully grouped your data into", n_strata, "strata!\n"))

    cat("\nYou have specified ")
    cat(bold(n_strata))
    cat(" strata, which explain ")
    cat(paste(bold(100 * round(solution$between.SS_DIV_total.SS, 4), "%", sep = "")))
    cat(" of the total \nvariation in the population.")

    cat("\n\nThe following table presents the mean and standard deviation \n(mean / sd) of each stratifying variable for each stratum. \nThe bottom row, 'Population,' presents the average values for \nthe entire inference population. The last column, 'n,' lists the \ntotal number of units in the inference population that fall \nwithin each stratum.\n\n")

    x2 <- data.frame(id, data_full, clusterID = solution$clusters) %>% tibble()

    population_summary_stats2 <- x2 %>% select(-c(all_of(idnum), clusterID)) %>%
      summarise_all(list(mean, sd)) %>%
      mutate_all(round, digits = 3)

    population_summary_stats <- population_summary_stats2 %>%
      names() %>% str_sub(end = -5) %>% unique() %>%
      lapply(function(x){
        unite_(population_summary_stats2, x, grep(x, names(population_summary_stats2), value = TRUE),
               sep = ' / ', remove = TRUE) %>% select(x)
      }) %>%
      bind_cols()

    summary_stats <- x2 %>%
      select(-all_of(idnum)) %>%
      group_by(clusterID) %>%
      summarize_if(is.numeric, mean) %>%
      left_join((x2 %>% select(-all_of(idnum)) %>% group_by(clusterID) %>% summarize_if(is.numeric, sd)),
                by = "clusterID", suffix = c("_fn1", "_fn2")) %>%
      mutate_all(round, digits = 3)

    summary_stats2 <- summary_stats %>%
      select(-clusterID) %>%
      names() %>%
      str_sub(end = -5) %>%
      unique() %>%
      lapply(function(x){
        unite_(summary_stats, x, grep(x, names(summary_stats), value = TRUE),
               sep = ' / ', remove = TRUE) %>% select(x)
      }) %>%
      bind_cols() %>% mutate(clusterID = summary_stats$clusterID) %>%
      select(clusterID, everything()) %>%
      left_join((x2 %>% group_by(clusterID) %>% count()), by = "clusterID") %>%
      mutate(clusterID = as.character(clusterID)) %>%
      add_row(tibble_row(clusterID = "Population", population_summary_stats, n = dim(x2)[1]))

    print(summary_stats2)

    simtab_m <- population_summary_stats2 %>%
      select(contains("fn1"))
    names(simtab_m) <- names(simtab_m) %>% str_sub(end = -5)
    sd_tab <- summary_stats %>%
      select(contains("fn2")) %>%
      add_row(tibble_row((population_summary_stats2 %>% select(contains("fn2")))))
    names(sd_tab) <- names(sd_tab) %>% str_sub(end = -5)
    sd_tab <- sd_tab %>%
      mutate(clusterID = summary_stats2$clusterID) %>%
      pivot_longer(-clusterID, names_to = "variable", values_to = "sd")
    mean_tab <- summary_stats %>%
      select(contains("fn1")) %>%
      add_row(tibble_row((population_summary_stats2 %>% select(contains("fn1")))))
    names(mean_tab) <- names(mean_tab) %>% str_sub(end = -5)
    mean_tab <- mean_tab %>%
      mutate(clusterID = summary_stats2$clusterID) %>%
      pivot_longer(-clusterID, names_to = "variable", values_to = "mn")
    counts_tab <- summary_stats2 %>%
      select(clusterID, n)

    heat_data <- left_join(mean_tab, sd_tab, by = c("clusterID", "variable")) %>%
      left_join(counts_tab, by = "clusterID")
    temporary_df <- data.frame(variable = unique(heat_data$variable),
                               population_mean = (heat_data %>% filter(clusterID == "Population") %>% select(mn))) %>%
      mutate(population_mean = mn) %>%
      select(-mn)
    heat_data <- heat_data %>% left_join(temporary_df, by = "variable") %>%
      mutate(deviation = case_when((mn - population_mean)/population_mean >= 0.7 ~ 0.7,
                                   (mn - population_mean)/population_mean <= -0.7 ~ -0.7,
                                   TRUE ~ (mn - population_mean)/population_mean))
    cluster_labels <- "Population"
    for(i in 2:(n_strata + 1)){
      cluster_labels[i] <- paste("Stratum", (i - 1))
    }

    heat_plot_final <- ggplot(data = heat_data) +
      geom_tile(aes(x = clusterID, y = variable, fill = deviation), width = 0.95) +
      geom_text(aes(x = clusterID, y = ((ncol(summary_stats) + 1)/2 - 0.15),
                    label = paste(n, "\nunits")), size = 3.4) +
      geom_label(aes(x = clusterID, y = variable,
                     label = paste0(round(mn, 1), "\n(", round(sd, 1), ")")),
                 colour = "black", alpha = 0.7,
                 size = ifelse((length(levels(heat_data$variable %>% factor())) + 1) > 7, 2, 3.5)) +
      geom_hline(yintercept = seq(1.5, (ncol(summary_stats) - 1), 1),
                 linetype = "dotted",
                 colour = "white") +
      scale_fill_gradientn(name = NULL, breaks=c(-0.5, 0, 0.5),
                           labels = c("50% \nBelow Mean",
                                      "Population\nMean",
                                      "50% \nAbove Mean"),
                           colours = c("#990000", "#CC0000",
                                       "white", "#3D85C6",
                                       "#0B5294"),
                           limits = c(-0.7, 0.7)) +
      scale_x_discrete(position = "top", expand = c(0, 0), labels = c(cluster_labels[-1], "Population")) +
      expand_limits(y = c(0, (ncol(summary_stats) + 1)/2 + 0.1)) +
      labs(y = NULL, x = NULL) +
      theme(panel.background = element_blank(),
            axis.ticks = element_blank(),
            axis.text = element_text(size = 10, colour = "grey15"),
            legend.key.height = unit(1, "cm"),
            legend.text = element_text(size = 10),
            legend.position = "right")

    print(heat_plot_final)

  }

  overall_output <- list(x2 = x2, solution = solution, n_strata = n_strata,
                         recruitment_lists = recruitment_lists,
                         population_summary_stats2 = population_summary_stats2,
                         summary_stats = summary_stats,
                         summary_stats2 = summary_stats2,
                         heat_data = heat_data, heat_plot_final = heat_plot_final,
                         idnum = idnum, variables = variables)

  class(overall_output) <- c("generalizer_output")

  return(invisible(overall_output))

}

