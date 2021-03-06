forecast.bats <- function(object, h, level=c(80,95), fan=FALSE, biasadj=NULL, ...)
{
  #Set up the variables
  if(any(class(object$y) == "ts"))
		ts.frequency <- frequency(object$y)
	else
		ts.frequency <- ifelse(!is.null(object$seasonal.periods), max(object$seasonal.periods), 1)

  if(missing(h))
  {
  	if(is.null(object$seasonal.periods))
      h <- ifelse(ts.frequency == 1, 10, 2*ts.frequency)
    else
      h <- 2 * max(object$seasonal.periods)
  }
	else if(h <= 0)
		stop("Forecast horizon out of bounds")

	if(fan)
		level <- seq(51,99,by=3)
	else
	{
		if(min(level) > 0 & max(level) < 1)
			level <- 100*level
		else if(min(level) < 0 | max(level) > 99.99)
			stop("Confidence limit out of range")
	}

	#Set up the matrices
	x <- matrix(0,nrow=nrow(object$x), ncol=h)
	y.forecast <- numeric(h)
	#w <- makeWMatrix(small.phi=object$damping.parameter, seasonal.periods=object$seasonal.periods, ar.coefs=object$ar.coefficients, ma.coefs=object$ma.coefficients)
	w <- .Call("makeBATSWMatrix", smallPhi_s = object$damping.parameter, sPeriods_s = object$seasonal.periods, arCoefs_s = object$ar.coefficients, maCoefs_s = object$ma.coefficients, PACKAGE = "forecast")
	#g <- makeGMatrix(alpha=object$alpha, beta=object$beta, gamma.vector=object$gamma.values, seasonal.periods=object$seasonal.periods, p=length(object$ar.coefficients), q=length(object$ma.coefficients))
	g <- .Call("makeBATSGMatrix", object$alpha, object$beta, object$gamma.values, object$seasonal.periods, length(object$ar.coefficients), length(object$ma.coefficients), PACKAGE="forecast")

	F <- makeFMatrix(alpha=object$alpha, beta=object$beta, small.phi=object$damping.parameter, seasonal.periods=object$seasonal.periods, gamma.bold.matrix=g$gamma.bold.matrix, ar.coefs=object$ar.coefficients, ma.coefs=object$ma.coefficients)

	#Do the forecast
	y.forecast[1] <- w$w.transpose %*% object$x[,ncol(object$x)]
	x[,1] <- F %*% object$x[,ncol(object$x)]# + g$g %*% object$errors[length(object$errors)]

	if(h > 1) {
		for(t in 2:h) {
			x[,t] <- F %*% x[,(t-1)]
			y.forecast[t] <- w$w.transpose %*% x[,(t-1)]
		}
	}
	##Make prediction intervals here
	lower.bounds <- upper.bounds <- matrix(NA,ncol=length(level),nrow=h)
	variance.multiplier <- numeric(h)
	variance.multiplier[1] <- 1
	if(h > 1) {
		for(j in 1:(h-1)) {
			if(j == 1) {
				f.running <- diag(ncol(F))
			} else {
				f.running <- f.running %*% F
			}
			c.j <- w$w.transpose %*% f.running %*% g$g
			variance.multiplier[(j+1)] <- variance.multiplier[j]+ c.j^2
		}
	}

	variance <- object$variance * variance.multiplier
	#print(variance)
	st.dev <- sqrt(variance)
	for(i in 1:length(level)) {
		marg.error <- st.dev * abs(qnorm((100-level[i])/200))
		lower.bounds[,i] <- y.forecast - marg.error
		upper.bounds[,i] <- y.forecast + marg.error

	}
	#Inv Box Cox transform if required
	if(!is.null(object$lambda))
	{
	  y.forecast <- InvBoxCox(y.forecast, object$lambda, biasadj, list(level = level, upper = upper.bounds, lower = lower.bounds))
		lower.bounds <- InvBoxCox(lower.bounds,object$lambda)
		if(object$lambda < 1) {
			lower.bounds<-pmax(lower.bounds, 0)
		}
		upper.bounds <- InvBoxCox(upper.bounds,object$lambda)
	}

  ##Calc a start time for the forecast
	start.time <- start(object$y)
	y <- ts(c(object$y,0), start=start.time, frequency=ts.frequency)
	fcast.start.time <- end(y)
	#Make msts object for x and mean
	x <- msts(object$y, seasonal.periods=(if(!is.null(object$seasonal.periods)) { object$seasonal.periods} else { ts.frequency}), ts.frequency=ts.frequency, start=start.time)
	fitted.values <- msts(object$fitted.values, seasonal.periods=(if(!is.null(object$seasonal.periods)) { object$seasonal.periods} else { ts.frequency}), ts.frequency=ts.frequency, start=start.time)
	y.forecast <- msts(y.forecast, seasonal.periods=(if(!is.null(object$seasonal.periods)) { object$seasonal.periods} else { ts.frequency}), ts.frequency=ts.frequency, start=fcast.start.time)
  upper.bounds <- msts(upper.bounds, seasonal.periods=(if(!is.null(object$seasonal.periods)) { object$seasonal.periods} else { ts.frequency}), ts.frequency=ts.frequency, start=fcast.start.time)
  lower.bounds <- msts(lower.bounds, seasonal.periods=(if(!is.null(object$seasonal.periods)) { object$seasonal.periods} else { ts.frequency}), ts.frequency=ts.frequency, start=fcast.start.time)
  colnames(upper.bounds) <- colnames(lower.bounds) <- paste0(level, "%")

  forecast.object <- list(model=object, mean=y.forecast, level=level, x=x, series=object$series,
	                        upper=upper.bounds, lower=lower.bounds, fitted=fitted.values,
	                        method=as.character(object), residuals=object$errors)
	if(is.null(object$series)){
	  forecast.object$series <- deparse(object$call$y)
	}
	class(forecast.object) <- "forecast"
	return(forecast.object)
}


as.character.bats <- function(x, ...) {
	name <- "BATS("
	if(!is.null(x$lambda)) {
		name <- paste(name, round(x$lambda, digits=3), sep="")
	} else {
		name <- paste(name, "1", sep="")
	}
	name <- paste(name, ", {", sep="")
	if(!is.null(x$ar.coefficients)) {
		name <- paste(name, length(x$ar.coefficients), sep="")
	} else {
		name <- paste(name, "0", sep="")
	}
	name <- paste(name, ",", sep="")
	if(!is.null(x$ma.coefficients)) {
		name <- paste(name, length(x$ma.coefficients), sep="")
	} else {
		name <- paste(name, "0", sep="")
	}
	name <- paste(name, "}, ", sep="")
	if(!is.null(x$damping.parameter)) {
		name <- paste(name, round(x$damping.parameter, digits=3), sep="")
	} else {
		name <- paste(name, "-", sep="")
	}
	name <- paste(name, ", ", sep="")
	if(!is.null(x$seasonal.periods)) {
    name <- paste(name,"{",sep="")
		for(i in x$seasonal.periods) {
			name <- paste(name, i, sep="")
			if(i != x$seasonal.periods[length(x$seasonal.periods)]) {
				name <- paste(name, ",", sep="")
			} else {
				name <- paste(name, "})", sep="")
			}
		}
	} else {
		name <- paste(name, "-)", sep="")
	}
	return(name)
}

