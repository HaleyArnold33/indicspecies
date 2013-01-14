#Finds the combination of clusters which is most significantly associated to each of the species patterns
multipatt <- function (x, cluster, func = "IndVal.g", duleg = FALSE, restcomb=NULL, max.order=NULL, control = permControl(), print.perm = FALSE)                                                                                              
{
	                                                                                                                              

# Matrix of possible cluster combinations
cl.comb <- function(clnames, max.order) {
	  k <- length(clnames)
    ep <- diag(1,k,k)
    names.ep <- clnames
    if(max.order>1) {
      for(j in 2:min(max.order, k)) {
        nco <- choose(k,j)
        co <- combn(k,j)
        epn <- matrix(0,ncol=nco,nrow=k)
        for(i in 1:ncol(co)) {
          epn[co[,i],i] <- 1
          names.ep <- c(names.ep, paste(clnames[co[,i]], collapse = "+"))
        }
        ep <- cbind(ep,epn)
      }
    }
    colnames(ep) <- names.ep
    return(ep)
}

# Correlation measures for combinations
rcomb <- function(x, comb, k, max.order, mode="group", restcomb=NULL) {
      nsps = ncol(x)
      N = dim(comb)[1]	
      ni = diag(t(comb) %*% comb)[1:k]
      tx <- t(x)
      aisp = (tx %*% comb)[,1:k]
      lisp = (tx^2 %*% comb)[,1:k]

  if(mode=="site") {
      lspK = rowSums(lisp)
      aspK = rowSums(aisp)		
      aspC = (tx %*% comb)
      nC = diag(t(comb) %*% comb)
  } else if(mode=="group") {
      aispni=sweep(aisp,2,ni,"/")
      lispni=sweep(lisp,2,ni,"/")
      #Corrected sum and length of species vectors
      lspK = (N/k) * rowSums(lispni)
      aspK = (N/k) * rowSums(aispni)

      if(max.order==1) {
	       aspC = (N/k)*aispni
	       nC = rep(N/k,k)
      } else {
	  #Corrected sum of species values in combinations
	  aspC = matrix(0,nrow=nsps,ncol=ncol(comb))
	  #Corrected size of cluster combinations
	  nC = vector(mode="numeric",length=ncol(comb))
	  #Level 1
	  aspC[,1:k] = aispni[,1:k]
	  nC[1:k] = 1
	  #Remaining levels
	  cnt = k+1	   
	  for(level in 2:max.order) {
	    co = combn(1:k,level)
	    for(j in 1:ncol(co)) {
		aspC[,cnt] = rowSums(aispni[,co[,j]])
		nC[cnt] = length(co[,j])
		cnt= cnt+1
	    }
	  }
	  aspC = (N/k)*aspC
	  nC = (N/k)*nC
      }
  }

  #Compute index
  num = N*aspC - aspK%o%nC
  den = sqrt(((N*lspK)-aspK^2)%o%(N*nC-(nC^2)))
  str=num/den
  colnames(str) <- colnames(comb)[1:ncol(str)]
  #Remove site group combinations that are not to be compared
  if(!is.null(restcomb)) {
    if(sum(restcomb %in% (1:ncol(str)))!=length(restcomb)) 
      stop(paste("One or more indices in 'restcomb' are out of range [1, ",ncol(str),"]",sep=""))      
    str <- str[,restcomb]
  }
  return(str)
}

# IndVal for combinations
indvalcomb <- function(x, comb, k, max.order, mode = "group", restcomb=NULL, indvalcomp=FALSE) {
  tx <- t(x)
  aisp = tx %*% comb
  dx <- dim(tx)
  nisp <- matrix(as.logical(tx),nrow=dx[1],ncol=dx[2]) %*% comb
  ni = diag(t(comb) %*% comb)
  nispni = sweep(nisp, 2, ni, "/")   
  if (mode == "site") A = sweep(aisp, 1, colSums(x), "/")  
  else {
    aispni = sweep(aisp[, 1:k], 2, ni[1:k], "/")
    asp = rowSums(aispni[, 1:k])
    if(max.order==1) A = sweep(aispni, 1, asp, "/")
    else {
      s = aispni 
      for(j in 2:max.order) {
        co <- combn(k,j)
        sn <- apply(co, 2, function(x) rowSums(aispni[,x]))
        s <- cbind(s, sn)
      }
	    A = sweep(s, 1, asp, "/")
  	} 
  }
  iv = sqrt(A * nispni)
  colnames(iv) <- colnames(comb)
  colnames(A) <- colnames(comb)
  colnames(nispni) <- colnames(comb)
  rownames(A) <- rownames(iv)
  rownames(nispni) <- rownames(iv)

  #Remove site group combinations that are not to be compared
  if(!is.null(restcomb)) {
    if(sum(restcomb %in% (1:ncol(iv)))!=length(restcomb)) 
      stop(paste("One or more indices in 'restcomb' are out of range [1, ",ncol(iv),"]",sep=""))
    iv = iv[,restcomb]
    A = A[,restcomb]
    nispni = nispni[,restcomb]
  }
  if(!indvalcomp) return(iv)
  else return(list(A=A,B=nispni, iv=iv))
}


  #function multipatt starts here	
  vegnames <- names(x)
  x <- as.matrix(x)                                                                                                                                
  nsps = ncol(x)
  clnames = levels(as.factor(cluster))
  k = length(clnames)
  nperm = control$nperm

  # Check parameters
  func= match.arg(func, c("r","r.g","IndVal.g","IndVal"))
  if(k<2) stop("At least two clusters are required.")
  if(sum(is.na(cluster))>0) stop("Cannot deal with NA values. Remove and run again.")
  if(sum(is.na(x))>0) stop("Cannot deal with NA values. Remove and run again.")
  if(is.null(max.order)) {
    if(func=="IndVal.g" || func=="IndVal") max.order=k
    else max.order = k-1
  } else {
    if(!is.numeric(max.order)) stop("Parameter max.order must be an integer.")
    if(func=="IndVal.g" || func=="IndVal") max.order = min(max(round(max.order),1),k)
    else max.order = min(max(round(max.order),1),k-1)
  }
  if(!is.null(restcomb)) { 
    restcomb = as.integer(restcomb)
  }

  # creates combinations from clusters
  if(duleg) max.order = 1 #duleg = TRUE overrides max.order

  # possible combinations (can also be used for permutations)
  combin <- cl.comb(clnames, max.order)	

  # discard combinations to discard that cannot be calculated because of order limitation
  restcomb = restcomb[restcomb<=ncol(combin)] 

  #Builds the plot membership matrix corresponding to combinations
  clind = apply(sapply(clnames,"==",cluster),1,which)
  comb <- combin[clind,]

  # Computes association strength for each group
  A = NULL
  B = NULL
  if(func=="r") str = rcomb(x, comb, k, max.order, mode = "site", restcomb = restcomb)
  else if(func=="r.g") str = rcomb(x, comb, k, max.order, mode = "group", restcomb = restcomb)
  else if(func=="IndVal") {
  	  IndVal = 	indvalcomb(x, comb, k, max.order, mode = "site", restcomb = restcomb, indvalcomp=TRUE)
  	  str = IndVal$iv
  	  A = IndVal$A
  	  B = IndVal$B
  	}
  else if(func=="IndVal.g") {
  	  IndVal = 	indvalcomb(x, comb, k, max.order, mode = "group", restcomb = restcomb, indvalcomp=TRUE)
  	  str = IndVal$iv
  	  A = IndVal$A
  	  B = IndVal$B
  	}

  # Maximum association strength
  maxstr = apply(str,1,max) 
  wmax <- max.col(str)
  #prepares matrix of results
  if(!is.null(restcomb))  m <- as.data.frame(t(combin[,restcomb][,wmax]))
  else  m <- as.data.frame(t(combin[,wmax]))
  dimnames(m) <- list(vegnames, sapply(clnames, function(x) paste("s", x, sep='.')))
  m$index <- wmax
  m$stat <- apply(str,1,max)

  #Perform permutations and compute p-values
  pv <- 1
  for (p in 1:nperm) {
  	  pInd = shuffle(length(cluster), control=control)
      tmpclind = clind[pInd]
	  combp = combin[tmpclind,]
      tmpstr <- switch(func,
	r   = rcomb(x, combp, k, max.order, mode = "site", restcomb = restcomb),
	r.g = rcomb(x, combp, k, max.order, mode = "group", restcomb = restcomb),
	IndVal = indvalcomb(x, combp, k, max.order, mode = "site", restcomb = restcomb),
	IndVal.g= indvalcomb(x, combp, k, max.order, mode = "group", restcomb = restcomb)
      )
      tmpmaxstr <- vector(length=nrow(tmpstr))
      for(i in 1:nrow(tmpstr)) tmpmaxstr[i] <- max(tmpstr[i,])	# apply is more slowly in this case
      pv = pv + (tmpmaxstr >= m$stat)
  }

  m$p.value <- pv/(1 + nperm)
  #Put NA for the p-value of species whose maximum associated combination is the set of all combinations
  m$p.value[m$index == (2^k-1)] <- NA

  if(!is.null(restcomb))  comb<-comb[,restcomb]
  
  a = list(call=match.call(), func = func, cluster = cluster, comb = comb, str = str, A=A, B=B, sign = m)
  class(a) = "multipatt"
  return(a)
}


