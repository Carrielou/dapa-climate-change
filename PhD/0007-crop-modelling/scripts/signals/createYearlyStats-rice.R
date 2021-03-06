#Julian Ramirez-Villegas
#February 2012
#CIAT / CCAFS / UoL
stop("Do not run whole thing")

#libraries
library(maptools); library(rgdal); library(raster)
data(wrld_simpl)

#sourcing important functions
#local
#src.dir <- "D:/_tools/dapa-climate-change/trunk/EcoCrop/src"
#src.dir2<-"D:/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"

#andromeda
#src.dir <- "/home/jramirez/dapa-climate-change/EcoCrop/src"
#src.dir2 <- "/home/jramirez/dapa-climate-change/PhD/0007-crop-modelling/scripts"

#eljefe
#src.dir <- "~/PhD-work/_tools/dapa-climate-change/trunk/EcoCrop/src"
#src.dir2<-"~/PhD-work/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"

source(paste(src.dir,"/createMask.R",sep=""))
source(paste(src.dir2,"/detrender-functions.R",sep=""))

#set the working folder
#bDir <- "F:/PhD-work/crop-modelling/GLAM/climate-signals-yield"
#bDir <- "/andromeda_data1/jramirez/crop-modelling/GLAM/climate-signals-yield"
#bDir <- "~/PhD-work/crop-modelling/GLAM/climate-signals-yield"
cropName <- "rice"
cd <- paste(bDir,"/",toupper(cropName),sep="")

#load detrended data
yieldData <- read.table(paste(cd,"/data/IND2-",cropName,".tab",sep=""),sep="\t",header=T)
rawData <- read.csv(paste(cd,"/data/detrended-IND2-",cropName,"-raw.csv",sep=""))
loeData <- read.csv(paste(cd,"/data/detrended-IND2-",cropName,"-loess.csv",sep=""))
linData <- read.csv(paste(cd,"/data/detrended-IND2-",cropName,"-linear.csv",sep=""))
quaData <- read.csv(paste(cd,"/data/detrended-IND2-",cropName,"-quadratic.csv",sep=""))
fouData <- read.csv(paste(cd,"/data/detrended-IND2-",cropName,"-fourier.csv",sep=""))

#raster with district IDs
rk <- raster(paste(cd,"/0_base_grids/india-1min-disid.asc",sep=""))
rk <- readAll(rk)

#Function to put the district data of a year into a raster and return it back
#preliminary step before the upscaling to gricells
outYearDir <- paste(cd,"/raster/yearly",sep="")
if (!file.exists(outYearDir)) {dir.create(outYearDir)}

#important fields
iyr <- 66; fyr <- 04
if (fyr < iyr) {
  tser <- (1900+iyr):(2000+fyr)
} else {
  tser <- 1900+(iyr:fyr)
}


for (dataType in c("raw","lin","loe","qua","fou")) {
  #dataType <- "fou"
  inyData <- get(paste(dataType, "Data",sep="")) #fouData
  outDataDir <- paste(outYearDir,"/",dataType,sep="")
  if (!file.exists(outDataDir)) {dir.create(outDataDir)}
  
  ####!!!!
  #or parallelise years
  library(snowfall)
  sfInit(parallel=T,cpus=12) #initiate cluster
  
  #export functions
  sfExport("createYearRaster")
  
  #export variables
  sfExport("inyData")
  sfExport("outYearDir")
  sfExport("outDataDir")
  sfExport("rk")
  sfExport("dataType")
  
  #run the control function
  system.time(sfSapply(as.vector(tser), controlYear))
  
  #stop the cluster
  sfStop()
}
