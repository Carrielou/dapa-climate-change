#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#June 2012

#CMIP5 skill analyses
#2. Calculate monthly climatological means for pr, tas, tasmin, tasmax, rd, and dtr

#Get CMIP5 weather data
library(raster)

#variables to be set
#src.dir <- "~/PhD-work/_tools/dapa-climate-change/trunk/PhD/0006-weather-data/scripts"
#src.dir2 <- "~/PhD-work/_tools/dapa-climate-change/trunk/PhD/0008-CMIP5"
#mdDir <- "/nfs/a102/eejarv/CMIP5/baseline"
#i <- 1 #gcm to process

#src.dir <- "D:/_tools/dapa-climate-change/trunk/PhD/0006-weather-data/scripts"
#src.dir2 <- "D:/_tools/dapa-climate-change/trunk/PhD/0008-CMIP5"
#mdDir <- "V:/eejarv/CMIP5/baseline"
#i <- 1 #gcm to process

source(paste(src.dir2,"/scripts/CMIP5-functions.R",sep=""))

yi <- 1961
yf <- 2000

#get the list of unprocessed GCMs
gcmChars <- read.table(paste(src.dir2,"/data/CMIP5gcms.tab",sep=""),sep="\t",header=T)
gcmList <- unique(gcmChars$GCM)

mList <- 1:length(gcmList)

ncpus <- length(mList)
if (ncpus>12) {ncpus <- 12}

#here do the parallelisation
#load library and create cluster
library(snowfall)
sfInit(parallel=T,cpus=ncpus)

#export functions
sfExport("src.dir")
sfExport("src.dir2")
sfExport("mdDir")
sfExport("yi")
sfExport("yf")

#run the function in parallel
system.time(sfSapply(as.vector(mList),wrapper_climatology))

#stop the cluster
sfStop()




########here calculate MMM (multi-model means)
#list of gcms
gcmChars <- read.table(paste(src.dir2,"/data/CMIP5gcms.tab",sep=""),header=T,sep="\t")
vnList <- c("pr","tas","dtr","rd")
gcmList <- unique(data.frame(GCM=gcmChars$GCM,ENS=gcmChars$Ensemble)) #model runs to average
gcmList$DIR <- paste(mdDir,"/",gcmList$GCM,"/",gcmList$ENS,"_climatology",sep="")

oDir <- paste(mdDir,"/multi_model_mean/r1i1p1_climatology",sep="")
if (!file.exists(oDir)) {dir.create(oDir,recursive=T)}

for (vn in vnList) {
  #vn <- vnList[1]
  cat("\nprocessing variable",vn,"\n")
  for (m in 1:12) {
    #m <- 1
    cat(m,". ",sep="")
    if (m < 10) {mth <- paste("0",m,sep="")} else {mth <- paste(m)}
    
    if (!file.exists(paste(oDir,"/",vn,"_",mth,".tif",sep=""))) {
      fList <- paste(gcmList$DIR,"/",vn,"_",mth,".tif",sep="")
      fPres <- as.character(sapply(fList,checkExists))
      fPres <- fPres[which(!is.na(fPres))]
      
      #loop through files, to load
      mList <- list()
      xr <- c(); yr <- c()
      for (i in 1:length(fPres)) {
        #cat(i,". ",sep="")
        #i=1
        rs <- raster(fPres[i])
        mList[[i]] <- rs
        xr <- c(xr,xres(rs)); yr <- c(yr,yres(rs))
      }
      
      #loop through files to resample to the lowest resolution possible
      mList_res <- list()
      sxr <- which(xr==min(xr))[1]
      for (i in 1:length(mList)) {
        mList_res[[i]] <- resample(mList[[i]],mList[[sxr]],method="ngb")
      }
      
      #a rasterstack is created and then use calc() to get the mean, and just write it
      rstk <- stack(mList_res)
      rsm <- calc(rstk,fun= function(x) {mean(x,na.rm=T)})
      rsm <- writeRaster(rsm,paste(oDir,"/",vn,"_",mth,".tif",sep=""),format="GTiff")
    }
  }
  cat("\n")
}






