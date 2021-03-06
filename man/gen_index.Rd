% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gen_index.R
\name{gen_index}
\alias{gen_index}
\title{Calculate Generalizability Index}
\usage{
gen_index(dat1B, dat2B)
}
\arguments{
\item{dat1B}{vector of probabilities of sample participation among individuals in the trial}

\item{dat2B}{vector of probabilities of sample participation among individuals in the population}
}
\value{
the generalizability index, a value between 0 and 1, where a higher score indicates greater similarity
}
\description{
This function is easiest to use through 'assess()' but can also be used independently.
}
\details{
It calculates the generalizability index, a value between 0 and 1, that represents how generalizable a given sample is to a given population on specified covariates. For more information on calculation and interpretation, please see Tipton (2014).
}
\references{
Tipton, E. (2014). How generalizable is your experiment? An index for comparing experimental samples and populations. \emph{Journal of Educational and Behavioral Statistics}, \emph{39}(6), 478-501.
}
