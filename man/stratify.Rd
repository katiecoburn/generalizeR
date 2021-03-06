% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stratify.R
\name{stratify}
\alias{stratify}
\title{Stratify a Population Data Frame}
\usage{
stratify(data, guided = TRUE, n_strata = NULL, variables = NULL, idnum = NULL)
}
\arguments{
\item{data}{The R object containing your population data frame}

\item{guided}{logical; defaults to TRUE. Whether the function should be guided (ask questions and behave interactively throughout) or not. If set to FALSE, must provide values for other arguments below}

\item{n_strata}{defaults to NULL. If guided is set to FALSE, must provide a number of strata to cluster population into}

\item{variables}{defaults to NULL. If guided is set to FALSE, must provide a character vector of the names of stratifying variables (from population data frame)}

\item{idnum}{defaults to NULL. If guided is set to FALSE, must provide a character vector of the name of the ID variable (from population data frame)}
}
\value{
The function returns a list of class "generalizer_output" that can be provided as input to \code{recruit()}. More information on the components of this list can be found above under "Details."
}
\description{
This function takes as input any data frame that you want to stratify into clusters. Typically, the goal of such stratification is sampling for generalizability. This function, and the others in this package, are designed to mimic the website https://www.thegeneralizer.org/.
}
\details{
The list contains 11 components: \code{x2}, \code{solution}, \code{n_strata}, \code{recruitment_lists}, \code{population_summary_stats2}, \code{summary_stats}, \code{summary_stats2}, \code{heat_data}, \code{heat_plot_final}, \code{idnum}, and \code{variables}.

\itemize{
\item{\code{x2}: }{a tibble with number of rows equal to the number of rows in the inference population (\code{data}) and number of columns equal to the number of stratifying variables (dummy-coded if applicable) plus the ID column (\code{idnum}) and a column representing stratum membership, \code{clusterID}}
}
}
\examples{
\donttest{
\dontrun{
# To get sample data; must first be installed using install_github("katiecoburn/generalizeRdata")
library(generalizeRdata)

# Guided:
stratify(ipeds)

# Not guided:
stratify(ipeds, guided = FALSE, n_strata = 4,
   variables = c("pct_female", "pct_white"), idnum = "unitid")
}
}
}
\references{
Tipton, E. (2014). Stratified sampling using cluster analysis: A sample selection strategy for improved generalizations from experiments. \emph{Evaluation Review}, \emph{37}(2), 109-139.

Tipton, E. (2014). How generalizable is your experiment? An index for comparing experimental samples and populations. \emph{Journal of Educational and Behavioral Statistics}, \emph{39}(6), 478-501.
}
