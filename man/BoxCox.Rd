\name{BoxCox}
\alias{BoxCox}
\alias{InvBoxCox}
\title{Box Cox Transformation}
\usage{BoxCox(x, lambda)
InvBoxCox(x, lambda, biasadj=FALSE, fvar=NULL)
}
\arguments{
\item{x}{a numeric vector or time series of class \code{ts}.}
\item{lambda}{transformation parameter.}
\item{biasadj}{Use adjusted back-transformed mean for Box-Cox transformations. If TRUE, point forecasts and fitted values are mean forecast. Otherwise, these points can be considered the median of the forecast densities.}
\item{fvar}{Optional parameter required if biasadj=TRUE. Can either be the forecast variance, or a list containing the interval \code{level}, and the corresponding \code{upper} and \code{lower} intervals.}
}
\description{BoxCox() returns a transformation of the input variable using a Box-Cox transformation.
InvBoxCox() reverses the transformation.
}
\details{The Box-Cox transformation is given by
\deqn{f_\lambda(x) =\frac{x^\lambda - 1}{\lambda}}{f(x;lambda)=(x^lambda - 1)/lambda}
if \eqn{\lambda\ne0}{lambda is not equal to 0}. For \eqn{\lambda=0}{lambda=0},
\deqn{f_0(x)=\log(x)}{f(x;0)=log(x)}.
}
\value{a numeric vector of the same length as x.
}
\references{Box, G. E. P. and Cox, D. R. (1964) An analysis of transformations. \emph{JRSS B} \bold{26} 211--246.
}
\seealso{\code{\link{BoxCox.lambda}}}
\author{Rob J Hyndman & Mitchell O'Hara-Wild}
\examples{
lambda <- BoxCox.lambda(lynx)
lynx.fit <- ar(BoxCox(lynx,lambda))
plot(forecast(lynx.fit,h=20,lambda=lambda))
}
\keyword{ts}
