###########################################################
#
# author: Ludwig Geistlinger
# date: 28 Feb 2011
#
# Combine result files of enrichment analyses
#
# Update:
#   27 May 2015: rank-based only combination
#
###########################################################

# Stouffer's combination of pvalues 
stouffer.comb <- function(pvals, two.sided=TRUE)
{
    ## remove NA
    pvals <- pvals[!is.na(pvals)]
    ## correct for two sided tests
    if(two.sided) pvals <- pvals/2
    ## z transformation
    z <- sum(-qnorm(pvals)) / sqrt(length(pvals))
    ## backtransformation
    p <- 1 - pnorm(abs(z))
    ## correct for two sided tests
    if(two.sided) p <- p * 2
    return(p)
}

# Fisher's combination of pvalues
fisher.comb <- function(pvals) {
    Xsq <- -2*sum(log(pvals))
    p <- 1 - pchisq(Xsq, df = 2*length(pvals))
    return(p)
}

# input: named ranking measure vector
# e.g. pvalues/scores of gene sets
# res <- c(0.01, 0.02, ..)
# names(res) <- c("gs1", "gs2", ..)
get.ranks <- function(res, rank.fun=c("rel.ranks", "abs.ranks"))
{
    if(is.function(rank.fun)) ranks <- rank.fun(res)
    else{
        rank.fun <- match.arg(rank.fun)
        GS.COL <- config.ebrowser("GS.COL")
        GSP.COL <- config.ebrowser("GSP.COL")
        ps <- res[, GSP.COL]
        names(ps) <- res[, GS.COL] 

        ucats <- unique(ps)
        ranks <- match(ps, ucats)
        if(rank.fun == "rel.ranks") 
            ranks <- ranks / length(ucats) * 100
        return(ranks)
    }
    return(ranks)
}

comb.ranks <- function(rankm, 
    comb.fun=c("mean", "median", "min", "max", "sum"))
{   
    if(is.function(comb.fun)) ranks <- apply(rankm, 1, comb.fun)
    else
    {   
        comb.fun <- match.arg(comb.fun)
        ranks <- apply(rankm, 1, 
            function(x) do.call(comb.fun, list(x, na.rm=TRUE)))
    }
    return(ranks)
}

###
# combine results of different enrichment analyises
# and compute average measures (rank & p-value)
###
# TODO: (1) weighted average ranks (to prioritize methods)
#       (2) what to do with equal average ranks (stouffer?)
comb.ea.results <- function(res.list, 
    rank.fun=c("rel.ranks", "abs.ranks"), 
    comb.fun=c("mean", "median", "min", "max", "sum"))
{
    GS.COL <- config.ebrowser("GS.COL")
    GSP.COL <- config.ebrowser("GSP.COL")

    # requires min. 2 results
    stopifnot(length(res.list) > 1)   

    # compute the intersect of gene sets in all result tables
    nr.res <- length(res.list)  
    gs <- res.list[[1]]$res.tbl[,GS.COL]
    for(i in seq_len(nr.res-1)) 
        gs <- intersect(gs, res.list[[i+1]]$res.tbl[,GS.COL])
    for(i in seq_len(nr.res))
    {
        curr <- res.list[[i]]$res.tbl 
        res.list[[i]]$res.tbl <- curr[curr[,GS.COL] %in% gs,]
    }
    nr.gs <- length(gs)

    # determine average ranks
    rankm <- matrix(0, nrow=nr.gs, ncol=nr.res)
    pvalm <- matrix(0.0, nrow=nr.gs, ncol=nr.res)
    
    for(i in seq_len(nr.res))
    {
        res.tbl <- res.list[[i]]$res.tbl
        ranks <- get.ranks(res.tbl, rank.fun=rank.fun)
        ord <- match(gs, res.tbl[,GS.COL])
        pvalm[,i] <- res.tbl[ord, GSP.COL]
        rankm[,i] <- ranks[ord] 
    }

    # compute average ranks
    av.ranks <- comb.ranks(rankm, comb.fun)
    if(is.character(comb.fun)) avr.cname <- toupper(match.arg(comb.fun))
    else avr.cname <- "COMB"
    avr.cname <- paste(avr.cname, "RANK", sep=".")

    # construct combined table
    res.tbl <- data.frame(rankm, av.ranks, pvalm)
    methods <- sapply(res.list, function(x) toupper(x$method))
    colnames(res.tbl) <- c(paste0(methods, ".RANK"), avr.cname, 
                paste0(methods, ".PVAL"))
    rownames(res.tbl) <- gs

    # order and format results
    res.tbl <- res.tbl[order(av.ranks),]
    res.tbl[,seq_len(nr.res+1)] <- round(res.tbl[,seq_len(nr.res+1)], digits=1)
    res.tbl[,(nr.res+2):ncol(res.tbl)] <- 
        signif(res.tbl[,(nr.res+2):ncol(res.tbl)], digits=3)
    res.tbl <- DataFrame(rownames(res.tbl), res.tbl)
    colnames(res.tbl)[1] <- GS.COL
    rownames(res.tbl) <- NULL

    res <- res.list[[1]]
    res$res.tbl <- res.tbl
    res$method <- "comb"
    res$nr.sigs <- min(nr.gs, config.ebrowser("NR.SHOW"))

    return(res)
}
