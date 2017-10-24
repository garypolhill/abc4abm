#!/usr/bin/env Rscript
#
# R script to check 'NAness' of runs

args <- commandArgs(T)

data <- read.csv(args[1])
n <- nrow(data)
names <- names(data)

param <- c("bioboost", "biospherism1", "biospherism2", "boostceil",
           "credit", "egoism1", "egoism2", "frame1", "frame2", "habitadjust",
	   "hedonism1", "hedonism2", "maxlinks", "visits", "planning1",
	   "planning2", "newsubcatapp", "newsubcatstep")

cat("NA analysis for data in", args[1], "\n")

eq0 <- c()
lt1pct <- c()
lt5pct <- c()
lt10pct <- c()
lt25pct <- c()
lt33pct <- c()
lt50pct <- c()
ge75pct <- c()
ge90pct <- c()
eq1 <- c()

for(i in 1:length(names)) {
  if(!(names[i] %in% param)) {
    ## It is not a parameter so we are interested in its NAs
    pNA <- length(which(is.na(data[,i]))) / n
    if(pNA == 0) {
      eq0[length(eq0) + 1] <- names[i]
    } else if(pNA < 0.01) {
      lt1pct[length(lt1pct) + 1] <- names[i]
    } else if(pNA < 0.05) {
      lt5pct[length(lt5pct) + 1] <- names[i]
    } else if(pNA < 0.1) {
      lt10pct[length(lt10pct) + 1] <- names[i]
    } else if(pNA < 0.25) {
      lt25pct[length(lt25pct) + 1] <- names[i]
    } else if(pNA < 0.33) {
      lt33pct[length(lt33pct) + 1] <- names[i]
    } else if(pNA < 0.5) {
      lt50pct[length(lt50pct) + 1] <- names[i]
    } else if(pNA == 1) {
      eq1[length(eq1) + 1] <- names[i]
    } else if(pNA >= 0.9) {
      ge90pct[length(ge90pct) + 1] <- names[i]
    } else if(pNA >= 0.75) {
      ge75pct[length(ge75pct) + 1] <- names[i]
    }

  }
}

cat("    No NA:", eq0, "\n")
cat("<   1% NA:", lt1pct, "\n")
cat("<   5% NA:", lt5pct, "\n")
cat("<  10% NA:", lt10pct, "\n")
cat("<  25% NA:", lt25pct, "\n")
cat("<  33% NA:", lt33pct, "\n")
cat("<  50% NA:", lt50pct, "\n")
cat(">= 75% NA:", ge75pct, "\n")
cat(">= 90% NA:", ge90pct, "\n")
cat("   All NA:", eq1, "\n")
cat("N =", n, "\n")

q(status = 0)
