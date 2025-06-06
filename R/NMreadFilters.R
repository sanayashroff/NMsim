##' Read data filters from a NONMEM model
##' @param file Control stream path
##' @param lines Control stream lines if already read from file
##' @param filters.only Return the filters only or also return the remaining text in a separate object? If `FALSE`, a list with the two objects is returned.
##' @param as.fun Function to run on the tables with filters.
##' @keywords internal

#### Keep internal - will be exported from NMdata

### the aim is to extract and classify filters. classify as IGNORE/ACCEPT, single character or comparisson.

## NMsim() needs a filters argument that can take such a data.frame. It should also accept just a string that represeents the filters if user wants to write something manually.

### NMapplyFilters should translate and apply.

NMreadFilters <- function(file,lines,filters.only=TRUE,as.fun) {
    
#### Section start: Dummy variables, only not to get NOTE's in pacakge checks ####
    
    . <- NULL
    variable <- NULL
    value <- NULL
    
### Section end: Dummy variables, only not to get NOTE's in pacakge checks
    
    if(missing(as.fun)) as.fun <- NULL
    as.fun <- NMdata:::NMdataDecideOption("as.fun",as.fun)
    
    if(missing(lines)) lines <- NULL
    if(missing(file)) file <- NULL
### this is assuming there is only one file, or that lines contains only one control stream.

    
    
    lines <- NMdata:::getLines(file=file,lines=lines)

    ## If these are not NULL, it can make trouble in NMreadSection.
    file <- NULL
    text <- NULL

### We leave meta data untouched. This part is due to a previous design of NMscanInput. 
    
    ##data.meta <- NMinfoDT(data)

    text2 <- NMreadSection(lines=lines,section="DATA",keep.comments=FALSE)
    text3 <- sub(";.*$","",text2)
    text3 <- gsub("\\t"," ",text3)
    
    ## replace the allowed IGN with IGNORE
    ## the single-chacter ones line @ or C. Here = is mandatory.
    ## conds.sc <- regmatches(text3, gregexpr(paste0("IGN(?:ORE)"," *= *[^ (+]"),text3))
    
    ## simplifying so IGNORE/IGN is always IGN
    text3 <- gsub("IGNORE","IGN",text3)

    
    ## ^(.* )* : if anything before IGN, there must be a space in between
    ## conds.sc <- regmatches(text3, gregexpr("^(.* )*(?:IGN) *=* *[^ (+=]",text3))
    conds.sc <- regmatches(text3, gregexpr("(?<![[:alnum:]])IGN *=* *[^ (+=]",text3,perl=T))
    conds.sc
    conds.sc <- do.call(c,conds.sc)
    
### getting rid of single char conditions
    text3 <- gsub("(?<![[:alnum:]])IGN *=* *[^ (+=]","",perl=TRUE,text3)
    
    ## check if IGNORE or ACCEPT are found. If both found, it is an error. 
    any.accepts <- any(grepl("ACCEPT",text3))
    any.ignores <- any(grepl("IGN",text3))
    ## if no filters found, just return data as is
    if(!any.accepts && !any.ignores && length(conds.sc)==0) return(data)
    if(any.accepts&&any.ignores) stop("IGNORE and ACCEPT are not allowed together according to Nonmem documentation.")
    
    if(any.ignores) {
        type.condition <- "IGN"
    } else {
        type.condition <- "ACCEPT"
    }
    
    
### expression-style ones
    ## this is not entirely correct.
### 1. A comma-separated list of expressions can be inside the ()s.
    ## 2. Expressions can be nested.
### 1. is handled below, 2 should be detected and give an error - interpretation not implemented.
    conds.expr <-
        regmatches(text3, gregexpr(paste0(type.condition," *=* *\\([^)]*\\)"),text3))
    conds.expr <- do.call(c,conds.expr)

    ## translating single-charaters
    ## name.c1 <- colnames(data)[1]
    scs <- sub(paste0("IGN"," *=* *(.+)"),"\\1",conds.sc)
    scs.all <- scs
    ## expressions.sc <- c()
    ## if(length(scs)&&grepl("@",scs)) {
### NM manual: @ means first non-blank is a-z or A-Z.
    ##     expressions.sc <- c(expressions.sc,paste0("!grepl(\"^ *[A-Za-z]\",",name.c1,")"))
    ##     scs <- scs[!grepl("@",scs)]
    ## }
    
    
### other single character ignores can be any character - except for space
    ## regstring <- "[[:punct:]]|[[:alpha:]]"

    ## if(length(scs)&&any(grepl(regstring,scs))) {
    ##     scs2 <- regmatches(scs,regexpr(regstring,scs))
    ##     expressions.sc <- c(expressions.sc,paste0("!grepl('^[",scs2,"]',`",name.c1,"`)"))
    ##     scs <- scs[!grepl(regstring,scs)]
    ## }

    ## if(length(scs)) stop(paste0("Not all single-character IGNORE statements were translated. This is left: ",scs))

    
    ## translating expression-style ones
    conds.list <- strsplit(
        gsub(paste0(type.condition," *=* *\\((.+)\\)"),"\\1",conds.expr)
       ,split=",")
    conds.char <- do.call(c,conds.list)

    dt.filters <- NULL
    if(length(scs.all)){
        
        dt.filters <- rbind(
            dt.filters
           ,
            data.table(type=type.condition,class="single-char",cond=scs.all)
        )
    }
    if(length(conds.char)){
        dt.filters <- rbind(dt.filters,
                            data.table(type=type.condition,class="var-compare",cond=conds.char)
                            )
    }

    dt.filters <- as.fun(dt.filters)
    if(filters.only) return(dt.filters)
### also return data.without.filters

    ## removing var-compare conditions to only have non-filters left
    text.nofilters <- regmatches(text3, gregexpr(paste0(type.condition," *=* *\\([^)]*\\)"),text3),invert=T)
    text.nofilters <- unlist(text.nofilters)
    text.nofilters <- text.nofilters[text.nofilters!=""]

    list(filters=dt.filters,text.nofilters=text.nofilters)
    
}


