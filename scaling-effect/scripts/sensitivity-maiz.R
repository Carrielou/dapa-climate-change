#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#Aug 2013
stop("!")

###
#do 96 sensitivity runs over the whole of West Africa
###

#load packages
library(rgdal); library(raster); library(maptools); library(rasterVis); data(wrld_simpl)
library(ggplot2); library(reshape2)

#source functions
src.dir <- "~/Repositories/dapa-climate-change/trunk/scaling-effect"
src.dir2 <- "~/Repositories/dapa-climate-change/trunk/PhD/0006-weather-data"
source(paste(src.dir,"/scripts/EcoCrop-model.R",sep=""))
source(paste(src.dir2,"/scripts/GHCND-GSOD-functions.R",sep=""))

#i/o directories and details
#bDir <- "/mnt/a102/eejarv/scaling-effect"
#bDir <- "/nfs/a102/eejarv/scaling-effect"
bDir <- "~/Leeds-work/scaling-effect"
clmDir <- paste(bDir,"/climate_data",sep="")
runDir <- paste(bDir,"/model-runs",sep="")
lsmDir <- paste(bDir,"/lsm",sep="")
#cascadeDir <- "/mnt/see-archive-12_a4scratch/eebjp"
#cascadeDir <- "/nfs/see-archive-12_a4scratch/eebjp"

sensDir <- paste(runDir,"/sens",sep="")
if (!file.exists(sensDir)) {dir.create(sensDir)}

#figure dir is local (on mbp)
figDir <- paste(bDir,"/figures_new",sep="")
if (!file.exists(figDir)) {dir.create(figDir)}

#model run details
trial <- 6
crop_name <- "maiz"

#get mask from CASCADE output
msk <- raster(paste(lsmDir,"/Glam_12km_lsm.nc",sep=""))
msk[which(msk[] < 0)] <- NA
msk[which(msk[] > 0)] <- 1 #1:length(which(msk[] > 0))

#make sensitivity table
sensruns <- expand.grid(TEMP=seq(-1,6,by=1),PREC=seq(-0.9,0.2,by=0.1))
if (!file.exists(paste(sensDir,"/sensitivity_runs.csv",sep=""))) {
  write.csv(sensruns,paste(sensDir,"/sensitivity_runs.csv",sep=""),quote=T,row.names=F)
}

#resolution
resol <- "12km_exp"
metDir <- paste(clmDir,"/cascade_",resol,sep="")

#loop the sensruns
for (i in 1:nrow(sensruns)) {
  #i <- 1
  cat("Sensitivity run",i,"\n")
  
  prec_p <- sensruns$PREC[i]
  temp_p <- sensruns$TEMP[i]
  
  tsensDir <- paste(sensDir,"/sens_",i,sep="")
  if (!file.exists(tsensDir)) {dir.create(tsensDir)}
  
  tsensMetDir <- paste(tsensDir,"/climate",sep="")
  if (!file.exists(tsensMetDir)) {dir.create(tsensMetDir)}
  
  trial <- 6
  outf <- paste(tsensDir,"/run_",trial,sep="")
  
  if (!file.exists(paste(outf,"/out_suit.png",sep=""))) {
    #create the meteorology for this run
    for (m in 1:12) {
      #m <- 1
      cat(m,"... ",sep="")
      if (!file.exists(paste(tsensMetDir,"/tmax_",m,".tif",sep=""))) {
        tmax <- raster(paste(metDir,"/tmax_",m,".tif",sep="")) + temp_p * 10
        tmax <- writeRaster(tmax,paste(tsensMetDir,"/tmax_",m,".tif",sep=""),format="GTiff",overwrite=F)
        rm(tmax)
      }
      
      if (!file.exists(paste(tsensMetDir,"/tmean_",m,".tif",sep=""))) {
        tmean <- raster(paste(metDir,"/tmean_",m,".tif",sep="")) + temp_p * 10
        tmean <- writeRaster(tmean,paste(tsensMetDir,"/tmean_",m,".tif",sep=""),format="GTiff",overwrite=F)
        rm(tmean)
      }
      
      if (!file.exists(paste(tsensMetDir,"/tmin_",m,".tif",sep=""))) {
        tmin <- raster(paste(metDir,"/tmin_",m,".tif",sep="")) + temp_p * 10
        tmin <- writeRaster(tmin,paste(tsensMetDir,"/tmin_",m,".tif",sep=""),format="GTiff",overwrite=F)
        rm(tmin)
      }
      
      if (!file.exists(paste(tsensMetDir,"/prec_",m,".tif",sep=""))) {
        prec <- raster(paste(metDir,"/prec_",m,".tif",sep=""))
        prec <- prec * (1 + prec_p)
        prec <- writeRaster(prec,paste(tsensMetDir,"/prec_",m,".tif",sep=""),format="GTiff",overwrite=F)
        rm(prec)
      }
      g=gc(); closeAllConnections()
    }
    cat("\n")
    
    #run EcoCrop with modified meteorology
    tkill <- 0; tmin <- 80; topmin <- 200; topmax <- 340; tmax <- 440 #trial 6
    rmin <- 100; ropmin <- 600; ropmax <- 1500; rmax <- 3000 #trial 6
    
    tpdate <- paste(runDir,"/",resol,"/calendar/plant_",resol,".tif",sep="")
    thdate <- paste(runDir,"/",resol,"/calendar/harvest_",resol,".tif",sep="")
    
    #run the model
    eco <- suitCalc(climPath=tsensMetDir, 
                    sowDat=tpdate,
                    harDat=thdate,
                    Gmin=NA,Gmax=NA,Tkmp=tkill,Tmin=tmin,Topmin=topmin,
                    Topmax=topmax,Tmax=tmax,Rmin=rmin,Ropmin=ropmin,
                    Ropmax=ropmax,Rmax=rmax, 
                    outfolder=outf,
                    cropname=crop_name,ext=".tif",cropClimate=F)
    
    png(paste(outf,"/out_suit.png",sep=""), height=1000,width=1500,units="px",pointsize=22)
    par(mar=c(3,3,1,2))
    rsx <- eco[[3]]; rsx[which(rsx[]==0)] <- NA; plot(rsx,col=rev(terrain.colors(20)))
    plot(wrld_simpl,add=T)
    grid(lwd=1.5)
    dev.off()
    
    rm(eco); g=gc(); rm(g); closeAllConnections()
  }
}


#loop sensitivity runs.
#1. crop to locations in 12km_exp (with top being lat=15)
#2. calculate average of all pixels
#3. calculate average of pixels where ahar >= 0.1
extn <- extent(msk)
extn@ymax <- 15
msk2 <- crop(msk, extn)
xy <- as.data.frame(xyFromCell(msk2,which(!is.na(msk2[]))))
xy <- cbind(cell=cellFromXY(msk2,xy[,c("x","y")]),xy)

#load area harvested and resample to climate grid
aharv <- raster(paste(bDir,"/calendar/Maize.crop.calendar/cascade_aharv.tif",sep=""))
fac <- round(xres(msk2)/xres(aharv))
aharv <- resample(aharv,msk2,method="ngb")
xy$aharv <- extract(aharv, xy[,c("x","y")])

tsuit0 <- raster(paste(sensDir,"/sens_74/","/run_",trial,"/",crop_name,"_suitability.tif",sep=""))
suit_vals0 <- extract(tsuit0, xy[,c("x","y")])
suit_valsh0 <- extract(tsuit0, xy[which(xy$aharv >= 0.1),c("x","y")])

outsens <- data.frame()
rawsens <- data.frame()
for (i in 1:nrow(sensruns)) {
  #i <- 1
  cat("Sensitivity run",i,"\n")
  
  prec_p <- sensruns$PREC[i]
  temp_p <- sensruns$TEMP[i]
  
  #load suitability raster
  tsensDir <- paste(sensDir,"/sens_",i,sep="")
  tsuit <- raster(paste(tsensDir,"/run_",trial,"/",crop_name,"_suitability.tif",sep=""))
  tsuit <- crop(tsuit, extn)
  
  #extract values for all pixels
  suit_vals <- extract(tsuit, xy[,c("x","y")])
  suit_m1 <- mean(suit_vals,na.rm=T)
  suitdiff <- (suit_vals - suit_vals0) / suit_vals0 * 100
  suitdiff <- suitdiff[which(!is.na(suitdiff))]
  suit_p1 <- length(which(suitdiff > 0)) / length(suitdiff)
  suit_n1 <- length(which(suitdiff < 0)) / length(suitdiff)
  suit_s1 <- sd(suitdiff, na.rm=T)
  
  outdfraw <- data.frame(sens=i,prec=prec_p,temp=temp_p,type="all",diff=suitdiff)
  
  #extract values for aharv>=0.1 pixels
  suit_vals <- extract(tsuit, xy[which(xy$aharv >= 0.1),c("x","y")])
  suit_m2 <- mean(suit_vals,na.rm=T)
  suitdiff <- (suit_vals - suit_valsh0) / suit_valsh0 * 100
  suitdiff <- suitdiff[which(!is.na(suitdiff))]
  suit_p2 <- length(which(suitdiff > 0)) / length(suitdiff)
  suit_n2 <- length(which(suitdiff < 0)) / length(suitdiff)
  suit_s2 <- sd(suitdiff, na.rm=T)
  
  outdfraw <- rbind(outdfraw, data.frame(sens=i,prec=prec_p,temp=temp_p,type="har",diff=suitdiff))
  
  #put in data.frame
  outdf <- data.frame(sens=i,prec=prec_p,temp=temp_p,suit_all=suit_m1,suit_all_pos=suit_p1,
                      suit_all_neg=suit_n1,suit_har=suit_m2,suit_har_pos=suit_p2,suit_har_neg=suit_n2,
                      suit_all_sd=suit_s1,suit_har_sd=suit_s2)
  outsens <- rbind(outsens,outdf)
  rawsens <- rbind(rawsens,outdfraw)
}

#4. calculate change in suitability with respect to the unperturbed run
#[(Y(T,P) - Y(T0,P0) ) / (Y(T0,P0) *100 ]All - [(Y(T,P) - Y(T0,P0) ) / (Y(T0,P0) *100 ]0.1.
suit0_all <- outsens$suit_all[which(outsens$prec == 0 & outsens$temp == 0)]
suit0_har <- outsens$suit_har[which(outsens$prec == 0 & outsens$temp == 0)]

outsens$reldiff_all <- (outsens$suit_all - suit0_all) / suit0_all * 100
outsens$reldiff_har <- (outsens$suit_har - suit0_har) / suit0_har * 100

#5. calculate difference between these two (i.e. Y_all - Y_har )
outsens$diff <- abs(outsens$reldiff_all) - abs(outsens$reldiff_har)
outsens$lab <- ""
outsens$lab[which(outsens$reldiff_all < 0 & outsens$reldiff_har < 0)] <- "-"
outsens$lab[which(outsens$reldiff_all > 0 & outsens$reldiff_har > 0)] <- "+"
outsens$lab[which(outsens$reldiff_all > 0 & outsens$reldiff_har < 0)] <- "*"
outsens$lab[which(outsens$reldiff_all < 0 & outsens$reldiff_har > 0)] <- "*"
outsens$lab[which(outsens$reldiff_all == 0 | outsens$reldiff_har == 0)] <- ""

#write sensitivity output
write.csv(outsens,paste(sensDir,"/sensitivity_result.csv",sep=""),quote=T,row.names=F)
write.csv(rawsens,paste(sensDir,"/sensitivity_result_raw.csv",sep=""),quote=T,row.names=F)

outsens <- outsens[which(outsens$temp != -1),]

#plot of sensitivity of 12km runs
hplot_df <- outsens[,c("prec","temp","reldiff_all")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = reldiff_all), colour = NA)
p <- p + scale_fill_gradient2(name="", low = "red", mid="white", high = "blue", 
                              midpoint=0, limits=c(-100,100),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_all.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


#fraction positive
hplot_df <- outsens[,c("prec","temp","suit_all_pos")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = suit_all_pos), colour = NA)
p <- p + scale_fill_gradient(name="", low = "white", high="black", 
                             limits=c(0,1),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_all_frac_positive.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


#fraction negative
hplot_df <- outsens[,c("prec","temp","suit_all_neg")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = suit_all_neg), colour = NA)
p <- p + scale_fill_gradient(name="", low = "white", high="black", 
                             limits=c(0,1),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_all_frac_negative.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


##same three plots but for har in 12km
#plot of sensitivity of 12km runs
hplot_df <- outsens[,c("prec","temp","reldiff_har")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = reldiff_har), colour = NA)
p <- p + scale_fill_gradient2(name="", low = "red", mid="white", high = "blue", 
                              midpoint=0, limits=c(-100,100),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_010.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


#fraction positive
hplot_df <- outsens[,c("prec","temp","suit_har_pos")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = suit_har_pos), colour = NA)
p <- p + scale_fill_gradient(name="", low = "white", high="black", 
                             limits=c(0,1),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_010_frac_positive.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


#fraction negative
hplot_df <- outsens[,c("prec","temp","suit_har_neg")]
hplot_df$prec <- as.factor(hplot_df$prec*100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = suit_har_neg), colour = NA)
p <- p + scale_fill_gradient(name="", low = "white", high="black", 
                             limits=c(0,1),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"),
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_010_frac_negative.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()


### 12km all minus 12km 010
#make a heatmap with this
hplot_df <- outsens[,c("prec","temp","diff","lab")]
hplot_df$prec <- as.factor(hplot_df$prec * 100)
hplot_df$temp <- as.factor(hplot_df$temp)

p <- ggplot(data=hplot_df, aes(temp, prec)) + geom_tile(aes(fill = diff), colour = NA)
p <- p + geom_text(aes(x=temp, y=prec, label=lab),fill="black")
p <- p + scale_fill_gradient2(name="", low = "red", mid="white", high = "blue", 
                              midpoint=0, limits=c(-20,20),guide="colourbar")
p <- p + theme(legend.key.height=unit(3.5,"cm"),legend.key.width=unit(1.25,"cm"), 
               legend.text=element_text(size=13),
               panel.background=element_rect(fill="white",colour="black"),
               axis.text=element_text(colour="black",size=13),
               axis.title=element_text(colour="black",size=15,face="bold"))
p <- p + labs(x = "Temperature change (K)", y = "Precipitation change (%)")

pdf(paste(figDir,"/heatmaps/heatmap_12km_all_minus_12km_010.pdf",sep=""), height=8,width=10,pointsize=14)
print(p)
dev.off()



# ###
# #produce beanplot of everything & aharv>=0.1
# #get values from unperturbed run
# 
# suit <- raster(paste(runDir,"/",resol,"/run_",trial,"/",crop_name,"_suitability.tif",sep=""))
# 
# library(beanplot)
# bplot_df <- xy
# bplot_df$suit <- extract(suit,xy[,c("x","y")])
# bplot_df <- bplot_df[which(!is.na(bplot_df$suit)),]
# 
# png(paste(figDir,"/beanplot_all_0.1_areas.png",sep=""), res=300,
#     height=1200,width=1200,units="px",pointsize=7)
# par(mar=c(2.5,4.5,1,1),lwd=0.8)
# beanplot(sample(bplot_df$suit,size=5000),bplot_df$suit[which(bplot_df$aharv >= 0.1)],bw=2,
#          col="grey 80",overallline = "median",what=c(1,1,1,0),xlab=NA,ylab="Crop suitability (%)",
#          xaxt = "n",border="black",beanlinewd=1.5)
# axis(1, at=c(1,2), labels=c("All","Harvested"))
# grid()
# dev.off()
# 
# 
# ####
# #now make a beanplot of each temperature gradient for all data and for ahar>=0.1
# sensruns <- read.csv(paste(sensDir,"/sensitivity_runs.csv",sep=""))
# sensruns <- cbind(IDRUN=1:nrow(sensruns), sensruns)
# 
# bplot_tsens <- xy
# for (tpert in seq(-1,6,by=1)) {
#   #tpert <- seq(-1,6,by=1)[1]
#   tsens <- sensruns[which(sensruns$TEMP == tpert & sensruns$PREC == 0),]
#   tsuit <- raster(paste(sensDir,"/sens_",tsens$IDRUN,"/run_",trial,"/",crop_name,"_suitability.tif",sep=""))
#   bplot_tsens$value <- extract(tsuit,xy[,c("x","y")])
#   names(bplot_tsens)[ncol(bplot_tsens)] <- paste("sens",tsens$IDRUN,sep="")
# }
# 
# bplot_tsens_h <- bplot_tsens[which(bplot_tsens$aharv >= 0.1),]
# 
# 
# png(paste(figDir,"/beanplot_sensitivity_all_areas.png",sep=""), res=300,
#     height=1000,width=1500,units="px",pointsize=7)
# par(mar=c(2.5,4.5,1,1),lwd=0.8)
# beanplot(bplot_tsens[sample(1:nrow(bplot_tsens),size=5000),paste("sens",c(73:80),sep="")],
#          col="grey 80",overallline = "median",what=c(1,1,1,0),xlab=NA,ylab="Crop suitability (%)",
#          xaxt = "n",border="black",beanlinewd=1.5)
# axis(1, at=c(1:8), labels=c("-1","0","+1","+2","+3","+4","+5","+6"))
# grid()
# dev.off()
# 
# 
# #beanplot for temperature sensitivity for areas above 0.1
# png(paste(figDir,"/beanplot_sensitivity_0.1_areas.png",sep=""), res=300,
#     height=1000,width=1500,units="px",pointsize=7)
# par(mar=c(2.5,4.5,1,1),lwd=0.8)
# beanplot(bplot_tsens_h[,paste("sens",c(73:80),sep="")],
#          col="grey 80",overallline = "median",what=c(1,1,1,0),xlab=NA,ylab="Crop suitability (%)",
#          xaxt = "n",border="black",beanlinewd=1.5)
# axis(1, at=c(1:8), labels=c("-1","0","+1","+2","+3","+4","+5","+6"))
# grid()
# dev.off()



