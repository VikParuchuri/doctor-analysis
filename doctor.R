setwd("~/vikparuchuri/doctor/")

is_installed <- function(mypkg) is.element(mypkg, installed.packages()[,1])

load_or_install<-function(package_names)
{
  for(package_name in package_names)
  {
    if(!is_installed(package_name))
    {
      install.packages(package_name,repos="http://lib.stat.cmu.edu/R/CRAN")
    }
    options(java.parameters = "-Xmx8g")
    library(package_name,character.only=TRUE,quietly=TRUE,verbose=FALSE)
  }
}

rename_col <- function(old, new, frame){
  for(i in 1:length(old)){
    names(frame)[names(frame) == old[i]] = new[i]
  }
  frame
}

load_or_install(c("igraph", "rpart", "tree", "bnlearn", "deal", "ggplot2","stringr","foreach","wordcloud","lsa","MASS","openNLP","tm","fastmatch","reshape","openNLPmodels.en",'e1071','gridExtra', 'XLConnect', 'reshape', 'plyr', 'RColorBrewer', 'rjson'))
non_predictors = c("ID", "joints", "referring_surgeon", "liveswith", "n_nice", "pre_n_sat", "n_count_sat", "n_count_nice", "joints", "knee_hip", "pre_anx_trait", "post_anx_trait", "tug_ratio", "knee_hip")

data = read.csv("ddr1.csv", stringsAsFactors=FALSE)
data$tug_delta = data$post_tug - data$pre_tug
data$tug_ratio = data$post_tug/data$pre_tug
data$depression_delta = data$post_depress - data$SUMBDI_admin
data$exp_pain_delta = data$pre_p_exp_pain - data$pre_p_cur_pain
data$sat_delta = data$post_p_sat - data$pre_p_sat
data$pain_delta = data$post_p_pain - data$pre_p_cur_pain
data$doctor_delta = data$post_s_p_sat - data$pre_d_sat
data = apply(data, 2, function(x){
  x[is.na(x)] = median(x, na.rm=TRUE)
  x
})

data = data.frame(apply(data, 2, function(x) as.numeric(x)))
data.gs = gs(data[, !names(data) %in% non_predictors])
plot(data.gs)

hc <- function(x, dat){
  t = cor(dat)
  r = t[,x]
  r = r[!names(r)==x]
  r[order(abs(r), decreasing = TRUE)]
}

dat = data[,!names(data) %in% non_predictors]

trees <- function(dat){
  res = list()
  for(i in 1:ncol(dat)){
    x = names(dat)[i]
    for(j in 1:ncol(dat)){
        if(j!=i){
          y = names(dat)[j]
          for(z in j:ncol(dat)){
            if(z!=i && z!=j){
              w = names(dat)[z]
              vals = single_tree(x, c(y,w), dat)
              res[[length(res) + 1]] = c(x, y, w, vals)
            }
          }
        }
    }
  }
  res
}

single_tree <- function(x, y, dat){
  predictions = cross_validate(x, y, dat)
  sqrt(sum((dat[,x] - predictions)^2)/length(predictions))
}

soft = c("post_p_pain", "post_anx_trait", "pre_anx_trait", "pre_p_exp_pain")
hard = c("post_tug", "pre_ox", "age")

cross_validate = function(x, y, dat){
  form = paste(x, "~.")
  fold_n = floor(nrow(data)/3)
  predictions = list()
  for(i in 1:3){
    start = fold_n * i
    end = fold_n * (i+1) -1
    if(i == 2){
      end = nrow(dat)
    }
    s_n = c()
    if(start > 1){
      s_n = 1:(start-1)
    }
    e_n = c()
    if(i < 2){
      e_n = (end+1):nrow(dat)
    }
    model = rpart(form, data=dat[c(s_n, e_n),c(y, x)])
    predictions[[length(predictions) + 1]] = predict(model, dat)
  }
  do.call(c, predictions)
}

plot_tree = function(x, y, dat){
  form = paste(x, "~.")
  model = rpart(form, data=dat[,c(y, x)])
  plot(model)
  text(model)
}


dat = data[data$knee_hip==1,!names(data) %in% non_predictors]

vals = trees(dat)
vf = data.frame(do.call(rbind, vals), stringsAsFactors=FALSE)
vf[,4] = as.numeric(vf[,4])
vf = vf[order(abs(vf[,4]), decreasing=TRUE),]
vfn = by(vf, vf[,1], function(x){
  x[,4] = as.numeric(x[,4])/sd(as.numeric(data[,x[1,1]]))
  x
})
vfn = do.call(rbind, vfn)
vfn = vfn[order(vfn[,4]),]
vfn = vfn[!vfn[,1] %in% c("tug_ratio", "tug_delta", "pre_tug", "post_tug", "knee_hip", "age", "post_o"),]

dat.gs = gs(dat[, !names(dat) %in% non_predictors])
plot(dat.gs)

additional_non = c("sex", "BMI", "religion", "maritalstate", "post_p_health", "religiousity")
cmat = cor(dat[,!names(dat) %in% c(non_predictors, additional_non)])
cmat = abs(cmat)
cutoff = .3
cmat[cmat < cutoff] = 0
graph <- graph.adjacency(cmat, weighted=TRUE, mode="undirected", diag=FALSE)
plot(graph)


wss <- (nrow(dat)-1)*sum(apply(dat,2,var))
for (i in 2:15) wss[i] <- sum(kmeans(dat, 
                                     centers=i)$withinss)
plot(1:15, wss, type="b", xlab="Number of Clusters",
     ylab="Within groups sum of squares")

clust = kmeans(dat, 7)

