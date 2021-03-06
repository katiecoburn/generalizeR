#' Recruit Units from a Population for Sampling
#'
#' This function works with the output of 'stratify()'. The user provides the number of units they wish to sample from their population dataset. The function tells the user how many to sample from each stratum and generates recruitment lists, one per stratum, which can either be saved to .csv files in any given directory or accessed later on.
#'
#' This function, and the others in this package, are designed to mimic the website https://www.thegeneralizer.org/.
#'
#' @param x output from 'stratify()', of S3 class 'generalizer_output'
#' @param guided logical; defaults to TRUE. Whether the function should be guided (ask questions and behave interactively throughout) or not. If set to FALSE, must provide values for other arguments below
#' @param number defaults to NULL. If guided is set to FALSE, must provide a number of units to sample
#' @param save_as_csv defaults to NULL. If guided is set to FALSE, specify whether or not to save recruitment lists to working directory; TRUE or FALSE
#' @return A one-element list containing the table that includes the number of units to sample per stratum
#' @export
#' @importFrom readr write_csv
#' @importFrom easycsv choose_dir

recruit <- function(x, guided = TRUE, number = NULL,
                    save_as_csv = FALSE){

  clusterID <- n <- proportion <- NULL

  blankMsg <- sprintf("\r%s\r", paste(rep(" ", getOption("width") - 1L), collapse = " "));

  if(!inherits(x, "generalizer_output"))
    stop("Argument 'x' must be an object of class \"generalizer_output\", \ncreated by running stratify().")

  cat("The generalizer output you've supplied consists of ", paste((x$summary_stats2 %>% filter(clusterID == "Population") %>% select(n))), " \npopulation units divided into ", paste(x$n_strata), " strata along these \nvariables: ", paste(x$variables, collapse = ", "), ".", sep = "")

  cat("\n\nGiven the number of units that you wish to recruit (your \ndesired sample size), this function can tell you how many units \nto recruit from each stratum and generate recruitment lists.\n\n")

  if(guided == TRUE){

    satisfied <- 0

    while(satisfied == 0){
      number <- as.numeric(readline(prompt = "# of units to recruit: "))

      if(number >= (x$summary_stats2 %>% filter(clusterID == "Population") %>% select(n))){

        satisfied <- 0
        cat("You cannot specify a sample size that exceeds the total \nnumber of units in your population.")

      }else{

        satisfied <- 1

      }
    }

    new_table <- x$heat_data %>% select(clusterID, n) %>%
      distinct(clusterID, .keep_all = TRUE) %>%
      mutate(Proportion = round(n/(dim(x$x2)[1]), digits = 3)) %>%
      mutate(To_Recruit = round(number * Proportion)) %>%
      filter(clusterID != "Population") %>%
      mutate(Cluster_ID = clusterID,
             Population_Units = n) %>%
      select(-c(clusterID, n)) %>%
      select(Cluster_ID, Population_Units, Proportion, To_Recruit) %>%
      data.frame()

    print(new_table, row.names = FALSE)

    cat("\n")
    cat(paste(x$n_strata), " recruitment lists have been generated, one per stratum. \nEach contains the ID information for the units, ranked in \norder of desirability. \n\nAttempt to recruit the desired proportionate number of units \nper stratum. If unsuccessful, recruit the next unit in the list, \nand continue until you have recruited the desired number of \nunits per stratum.", sep = "")

    if(menu(choices = c("Yes", "No"), title = cat("\n\nWould you like to save these lists as .csv files?")) == 1){

      cat("\nThe lists will be saved as 'recruitment_list_for_#', one for \neach stratum. ")
      cat("Where should they be saved?\n\n")
      # filepath <- readline(prompt = "Enter a file path (Example: /Users/xdfdf/Desktop/): ")
      filepath <- easycsv::choose_dir()

      for(i in 1:(x$n_strata)){
        filename <- paste(filepath, "recruitment_list_for_", i, ".csv", sep="")
        write_csv(x$recruitment_lists[[i]], path = filename)
      }

      cat("\nLists saved successfully. You can also access these \nlists later from '", paste(deparse(substitute(x))), "' by using '$recruitment_lists'.", sep = "")

      }else{

      cat("You can access these lists later from '", paste(deparse(substitute(x))), "' by using '$recruitment_lists'.", sep = "")

    }

  }else{

    # Non-guided stuff goes here.

    if(is.null(number)){
      stop("You must specify the number of units that you want to recruit.")
    }

    if(!inherits(x, "generalizer_output"))
      stop("Argument 'x' must be an object of class \"generalizer_output\", \ncreated by running stratify().")

    cat("The generalizer output you've supplied consists of ", paste((x$summary_stats2 %>% filter(clusterID == "Population") %>% select(n))), " \npopulation units divided into ", paste(x$n_strata), " strata along these \nvariables: ", paste(x$variables, collapse = ", "), ".\n\n", sep = "")

    new_table <- x$heat_data %>% select(clusterID, n) %>%
      distinct(clusterID, .keep_all = TRUE) %>%
      mutate(proportion = round(n/(dim(x$x2)[1]), digits = 3)) %>%
      mutate(to_recruit = round(number * proportion)) %>%
      filter(clusterID != "Population") %>%
      data.frame()

    print(new_table, row.names = FALSE)

    cat("\n", paste(x$n_strata), " recruitment lists have been generated, one per stratum. \nEach contains the ID information for the units, ranked in \norder of desirability. \n\nAttempt to recruit the desired proportionate number of units \nper stratum. If unsuccessful, recruit the next unit in the list, \nand continue until you have recruited the desired number of \nunits per stratum.", sep = "")

    if(save_as_csv == TRUE){

      cat("\n\nYou've chosen to save these lists as .csv files. \nThe lists will be saved as 'recruitment_list_for_#', one for \neach stratum. They have been saved to your current working directory.")

      for(i in 1:(x$n_strata)){
        filename <- paste("recruitment_list_for_", i, ".csv", sep="")
        write_csv(x$recruitment_lists[[i]], path = filename)
      }

    }else{
      cat("You can access these lists later from", paste(deparse(substitute(x))), " by using '$recruitment_lists'.", sep = "")
    }

  }

  output <- list(new_table)
  return(invisible(output))

}
