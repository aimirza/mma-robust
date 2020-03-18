#to organize data
data.org<-function(x,y,pred,mediator=NULL,contmed=NULL,binmed=NULL,binref=NULL,catmed=NULL,
                   catref=NULL,jointm=NULL,refy=rep(NA,ncol(data.frame(y))), 
                   family1=as.list(rep(NA,ncol(data.frame(y)))),
                   predref=rep(NA,ncol(data.frame(pred))),alpha=0.1,alpha2=0.1,testtype=1, w=NULL,cova=NULL)
{cattobin<-function(x,cat1,cat2=rep(1,length(cat1))) #binaryize the categorical pred in x, cat1 are the column numbers of multicategorical variables cat2 are the reference groups
{ad1<-function(vec)
{vec1<-vec[-1]
vec1[vec[1]]<-1
vec1
}
dim1<-dim(x)
catm<-list(n=length(cat1))
g<-dim1[2]-length(cat1)
ntemp<-colnames(x)[cat1]
j<-1
for (i in cat1)
{a<-factor(x[,i])
d<-rep(0,dim1[1])
b<-sort(unique(a[a!=cat2[j]]))
l<-1
for (k in b)
{d[a==k]<-l
l<-l+1}
d[a==cat2[j]]<-l
f<-matrix(0,dim1[1],l-1) 
colnames(f)<-paste(ntemp[j],b,sep="") #changed for error info
hi<-d[d!=l & !is.na(d)]
f[d!=l & !is.na(d),]<-t(apply(cbind(hi,f[d!=l & !is.na(d),]),1,ad1))
f[is.na(d),]<-NA
x<-cbind(x,f)
catm<-append(catm,list((g+1):(g+l-1)))
g<-g+length(b)
j<-j+1
}
xname=colnames(x)
x<-x[,-cat1]
x=data.frame(x)
colnames(x)=xname[-cat1]
list(x=x,catm=catm) #cate variables are all combined to the end of x, catm gives the column numbers in x for each cate predictor
}

colnum<-function(vec,cutx) 
{z<-vec
 for (i in 1:length(vec))
   z[i]<-vec[i]-sum(vec[i]>cutx)
 z}

#y2 is the response dataframe
y2<-data.frame(y)                     #consider multivarite or multicategorical responses
ny<-ncol(y2)
y_type<-rep(4,ny)                     #1 is continuous, 2 is binary, 3 is multi-categorical, 4 is survival
for (i in 1:ny)
{if(class(y2[,i])!="Surv")
  if(nlevels(droplevels(as.factor(y2[,i])))==2)   
  {y_type[i]<-2
   if(is.na(family1[[i]]))
    family1[[i]] = binomial("logit")
   if(!is.na(refy[i]))
    y2[,i]<-ifelse(y2[,i]==refy[i],0,1)
  else
   {refy[i]<-levels(droplevels(as.factor(y2[,i])))[1]
    y2[,i]<-ifelse(as.factor(y2[,i])==refy[i],0,1)}
 }
 else if(is.character(y2[,i]) | is.factor(y2[,i]))
 {y_type[i]<-3
  y2[,i]<-droplevels(y2[,i])  #drop those empty levles
  if(is.na(refy[i]))
    refy[i]<-levels(as.factor(y2[,i]))[1]
 }
 else
 {y_type[i]=1
  if(is.na(family1[[i]]))
   family1[[i]] = gaussian(link = "identity")
 }
}

if(sum(y_type==3)>0) #transfer the multicategorical type response
{temp1<-(1:length(y_type))[y_type==3]
 temp2<-cattobin(y2,temp1,refy[temp1])
 y2<-data.frame(temp2$x)
 y_type<-y_type[-temp1]
 y_type<-c(y_type,rep(2,ncol(y2)-length(y_type)))
 family1[[temp1]]<-NULL
 family1<-append(family1,rep(list(binomial("logit")),ncol(y2)-length(family1)))
}

xnames<-colnames(x)
if(!is.null(cova)){
  if(length(grep("for.m",names(cova)))==0)
   cova_names=colnames(cova)
  else 
   cova_names=colnames(cova[[1]])}

#predictors can be of any type, pred is the exposure vector/matrix
pred_names=names(pred)
pred1<-data.frame(pred)

if(is.null(pred_names))
 pred_names="pred"
colnames(pred1)=pred_names
binpred=NULL           #is now null or column numbers of binary predictors in pred
catpred=NULL
contpred=NULL
catn=0

npred=ncol(pred1)
for (i in 1:npred)
 if(nlevels(droplevels(as.factor(pred1[,i])))==2)
 {if(!is.na(predref[i]))
      pred1[,i]<-as.factor(ifelse(pred1[,i]==predref[i],0,1))
  else
      {pred1[,i]<-as.factor(pred1[,i])
       pred1[,i]<-as.factor(ifelse(pred1[,i]==levels(droplevels(pred1[,i]))[1],0,1))}
  binpred=c(binpred,i)
 }
 else if(is.character(pred1[,i]) | is.factor(pred1[,i]))
 {pred1[,i]=droplevels(pred1[,i])
  temp.pred=data.frame(pred1[,i])
  colnames(temp.pred)=pred_names[i]
  catn=catn+1
  if(!is.na(predref[i]))
   pred.temp1<-cattobin(temp.pred,1,predref[i])
  else
   pred.temp1<-cattobin(temp.pred,1,levels(as.factor(pred1[,i]))[1])
  pred1[,i]=pred.temp1$x[,1]
  catpred[[catn]]=c(i,pred.temp1$catm[[2]][-1]+ncol(pred1)-1)
  pred1=cbind(pred1,pred.temp1$x[,-1])
 }
else
  contpred=c(contpred,i)

pred_names=names(pred1)
pred<-data.frame(pred1)
colnames(pred)=pred_names

if(is.character(contmed))
  contmed<-unlist(sapply(contmed,grep,xnames))
if(is.character(binmed))
  binmed<-unlist(sapply(binmed,grep,xnames))
if(is.character(catmed))
  catmed<-unlist(sapply(catmed,grep,xnames))
if(!is.null(jointm))
  for (i in 2:length(jointm))
   if(is.character(jointm[[i]]))
     jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))

if(!is.null(binmed))  #revise: binref does not have to be null or full, & is.null(binref)
 {j<-1
  for(i in binmed)
  {x[,i]=as.factor(x[,i])
   if(is.null(binref))
   binref[i]=levels(x[,i])[1]
   else if(is.na(binref[i]))
     binref[i]=levels(x[,i])[1]
   j<-j+1}}

if(!is.null(catmed))   #revise: catref does not have to be null or full, & is.null(catref)
 {j<-1 
  for(i in catmed)
  {x[,i]=as.factor(x[,i])
    if(is.null(catref))
      catref[j]=levels(x[,i])[1]
    else if(is.na(catref[j]))
      catref[j]=levels(x[,i])[1]
   j<-j+1}}

if(!is.null(mediator))   #for all potential mediators
 {if(is.character(mediator))
   mediator<-unlist(sapply(mediator,grep,xnames))
  for (i in 1:length(mediator))
    {if(is.character(x[,mediator[i]]))
      x[,mediator[i]]<-as.factor(x[,mediator[i]])
     if(is.factor(x[,mediator[i]]) | nlevels(as.factor(x[,mediator[i]]))==2)
       if(nlevels(as.factor(x[,mediator[i]]))==2)
       {if(sum(binmed==mediator[i])==0)
        {x[,mediator[i]]<-as.factor(x[,mediator[i]])
         binmed<-c(binmed,mediator[i])
         binref<-c(binref,(levels(x[,mediator[i]]))[1])
         }}
      else
       {if(sum(catmed==mediator[i])==0)
        {catmed<-c(catmed,mediator[i])
         catref<-c(catref,levels(x[,mediator[i]])[1])}}
     else if(sum(contmed==mediator[i])==0 & sum(catmed==mediator[i])==0)
        contmed<-c(contmed,mediator[i])}
 }

if(!is.null(jointm))  #mediators that should be jointly considered are forced in as mediators
{joint<-NULL 
 for (i in 2:(jointm[[1]]+1))
   joint=c(joint,jointm[[i]])
 joint1<-unique(joint)
 
 if(!is.null(contmed))
 {cont1<-rep(F,length(contmed))
  for (i in 1:length(contmed))
    cont1[i]<-ifelse(sum(contmed[i]==joint1)>0,T,F)
 }
 if(!is.null(binmed))
 {bin1<-rep(F,length(binmed))
  for (i in 1:length(binmed))
    bin1[i]<-ifelse(sum(binmed[i]==joint1)>0,T,F)
 }
 if(!is.null(catmed))
 {cat1<-rep(F,length(catmed))
  for (i in 1:length(catmed))
    cat1[i]<-ifelse(sum(catmed[i]==joint1)>0,T,F)
 }
}
else
{if(!is.null(contmed))
  cont1<-rep(F,length(contmed))
 
 if(!is.null(binmed))
   bin1<-rep(F,length(binmed))
 
 if(!is.null(catmed))
   cat1<-rep(F,length(catmed))
}

if(!is.null(binmed))
{j<-1
 for (i in binmed)
 {x[,i]<-ifelse(x[,i]==binref[j],0,1)
  j<-j+1}
}

if(!is.null(catmed))
{tempx<-cattobin(x,catmed,catref)
 newx<-tempx$x
 catnewx<-tempx$catm}
else newx<-x

#newx1<-cbind(newx1,pred) #add the predictor(s) back
#delete variables that are not significant
fullmodel<-NULL
fullmodel1<-NULL
type3<-NULL
for (j in 1:length(y_type))
{if(y_type[j]==4 & is.null(w))
  {fullmodel1[[j]]<-coxph(y2[,j]~.,data=data.frame(cbind(x,pred)))
   fullmodel[[j]]<-summary(fullmodel1[[j]])}
 else if (y_type[j]==4)
  {fullmodel1[[j]]<-coxph(y2[,j]~.,data=data.frame(cbind(x,pred)), weights=w)
   fullmodel[[j]]<-summary(fullmodel1[[j]])}
 else
  {fullmodel1[[j]]<-glm(y2[,j]~.,data=data.frame(cbind(x,pred)),family=family1[[j]],weights=w) #use type three error to test the full model
   fullmodel[[j]]<-summary(fullmodel1[[j]])}
 type3[[j]]<-Anova(fullmodel1[[j]],type="III")
 if(j==1)
   P1<-type3[[j]][,3]
 else
   P1<-cbind(P1,type3[[j]][,3])  ##########
}
xname<-colnames(x)
xnames3<-rownames(type3[[1]])

if(testtype==2){  #
P1<-matrix(NA,length(xnames3),ncol(y2))  #the type III for predictor and one mediator only model
} #

P1<-data.matrix(P1)
rownames(P1)<-xnames3
colnames(P1)<-colnames(y2)


prednames<-colnames(pred)
covr.cont<-rep(F,length(contmed))
covr.bin<-rep(F,length(binmed))
covr.cat<-rep(F,length(catmed))

for (j in 1:ncol(y2))  #adjust for multivariate response
{if(testtype==2)
 {if(y_type[j]==4 & is.null(w))
   temp.fullmodel1<-coxph(y2[,j]~.,data=pred)
  else if (y_type[j]==4)
   temp.fullmodel1<-coxph(y2[,j]~.,data=pred,weights=w)
  else
   temp.fullmodel1<-glm(y2[,j]~.,data=pred,family=family1[[j]],weights=w) 
  temp.type3<-Anova(temp.fullmodel1,type="III")
  for (k in 1:ncol(pred))
   P1[grep(prednames[k],xnames3),j]<-temp.type3[rownames(temp.type3)==prednames[k],3]
 }

if(!is.null(contmed))
  for (i in 1:length(contmed))
   if(testtype==1)
    covr.cont[i]<-ifelse(type3[[j]][xnames3==xname[contmed[i]],3]<alpha,T,covr.cont[i])
   else if(testtype==2)
   {temp.data<-cbind(x[,contmed[i]],pred)
    names(temp.data)<-c(xname[contmed[i]],names(pred))
    if(y_type[j]==4)
     temp.fullmodel1<-coxph(y2[,j]~.,data=data.frame(temp.data),weights=w)
    else
     temp.fullmodel1<-glm(y2[,j]~.,data=data.frame(temp.data),family=family1[[j]],weights=w) 
    temp.type3<-Anova(temp.fullmodel1,type="III")
    temp.p1<-temp.type3[rownames(temp.type3)==xname[contmed[i]],3]
    P1[grep(xname[contmed[i]],xnames3),j]<-temp.p1
    covr.cont[i]<-ifelse(temp.p1<alpha,T,covr.cont[i])
   }

 if(!is.null(binmed))
  for (i in 1:length(binmed))
   if(testtype==1)
    covr.bin[i]<-ifelse(type3[[j]][xnames3==xname[binmed[i]],3]<alpha,T,covr.bin[i])
   else if(testtype==2)
   {temp.data<-cbind(x[,binmed[i]],pred)
    names(temp.data)<-c(xname[binmed[i]],names(pred))
    if(y_type[j]==4)
     temp.fullmodel1<-coxph(y2[,j]~.,data=data.frame(temp.data),weights=w)
    else
     temp.fullmodel1<-glm(y2[,j]~.,data=data.frame(temp.data),family=family1[[j]],weights=w) 
   temp.type3<-Anova(temp.fullmodel1,type="III")
   temp.p1<-temp.type3[rownames(temp.type3)==xname[binmed[i]],3]
   P1[grep(xname[binmed[i]],xnames3),j]<-temp.p1
   covr.bin[i]<-ifelse(temp.p1<alpha,T,covr.bin[i])
  }
 
 if(!is.null(catmed))
  for (i in 1:length(catmed))
   if(testtype==1)
     covr.cat[i]<-ifelse(type3[[j]][xnames3==xname[catmed[i]],3]<alpha,T,covr.cat[i]) 
   else if(testtype==2)
    {temp.data<-cbind(x[,catmed[i]],pred)
     names(temp.data)<-c(xname[catmed[i]],names(pred))
     if(y_type[j]==4)
      temp.fullmodel1<-coxph(y2[,j]~.,data=data.frame(temp.data),weights=w)
     else
      temp.fullmodel1<-glm(y2[,j]~.,data=data.frame(temp.data),family=family1[[j]],weights=w) #use type three error to test the full model
    temp.type3<-Anova(temp.fullmodel1,type="III")
    temp.p1<-temp.type3[rownames(temp.type3)==xname[catmed[i]],3]
    P1[grep(xname[catmed[i]],xnames3),j]<-temp.p1
    covr.cat[i]<-ifelse(temp.p1<alpha,T,covr.cat[i])
   }
} 

if(!is.null(contmed))
 {covr.cont<-ifelse(covr.cont|cont1,T,F)
  cont2<-cont1[covr.cont]
  contmed1<-contmed[covr.cont]}
if(!is.null(binmed))
 {covr.bin<-ifelse(covr.bin+bin1>0,T,F) 
  bin2<-bin1[covr.bin]
  binmed1<-binmed[covr.bin]}
if(!is.null(catmed))
 {covr.cat<-ifelse(covr.cat+cat1>0,T,F)
  cat2<-cat1[covr.cat]
  catmed1<-catmed[covr.cat]
  catref1<-catref[covr.cat]}

a1<-c(contmed,binmed,catmed)
a2<-c(covr.cont,covr.bin,covr.cat)

cutx<-a1[!a2]

if (sum(a2)==0)
  return ("no mediators found")
else if(length(cutx)==0)
{newx1<-x
 contm1<-contmed
 binm1<-binmed
 catm1<-catmed
 catref1<-catref
}
else {newx1<-data.frame(x[,-cutx])
      if(sum(covr.cont)==0)
       contm1<-NULL  
      else 
       contm1<-colnum(contmed[covr.cont],cutx)
      if(sum(covr.bin)==0)
        binm1<-NULL
      else 
        binm1<-colnum(binmed[covr.bin],cutx)
      if(sum(covr.cat)==0)
      {catm1<-NULL
       catref1<-NULL}
      else 
      {catm1<-colnum(catmed[covr.cat],cutx)
       catref1<-catref[covr.cat]}
      if(!is.null(jointm))
        for(i in 2:(jointm[[1]]+1))
          jointm[[i]]<-colnum(jointm[[i]],cutx)
}

#delete nonmediators
rela_var<-NULL               #to store the relationships between mediators and predictor   
rela_p<-NULL
name_newx<-colnames(newx1)
nx=ncol(pred)
indi=NULL                   #to allow for covariates for mediators
pred1=pred                  #indi indicates which mediator(column) in newx1 needs covariates
if(is.null(cova))
  pred2=NULL                 #pred2 is the set of predictors for mediators if extra covariates are needed
else if (length(grep("for.m",names(cova)))==0)
  {pred2=cbind(pred,cova)
   indi=c(contm1,binm1,catm1)}
else
 {pred2=cbind(pred,cova[[1]])
  for(i in 1:length(cova[[2]]))
    indi=c(indi,grep(cova[[2]][i],name_newx))
  if(length(indi)==0)
    cova=NULL
 }

 contm2<-contm1
 if(length(contm1)>0)
  {med.cont<-rep(F,length(contm1))
   for (i in 1:length(contm1))
   {if (!(contm1[i] %in% indi))          #to check if the covariates are needed to estimate the mediator
     tempmodel<-summary(glm(newx1[,contm1[i]]~.,weights=w,data=pred1)) #allowing multivariate predictors
    else 
     tempmodel<-summary(glm(newx1[,contm1[i]]~.,weights=w,data=pred2)) #allowing multivariate predictors
    med.cont[i]<-ifelse(min(tempmodel$coef[2:(nx+1),4])<alpha2,T,F)
    rela_var<-c(rela_var,name_newx[contm1[i]])
    rela_p<-rbind(rela_p,tempmodel$coef[2:(nx+1),4])
   }
  med.cont<-ifelse(med.cont+cont2>0,T,F)
  contm2<-contm1[med.cont]}

 binm2<-binm1
 if(length(binm1)>0) 
 {med.bin<-rep(F,length(binm1))
  for (i in 1:length(binm1))   
    {if (!(binm1[i]%in%indi))          #to check if the covariates are needed to estimate the mediator
       tempmodel<-summary(glm(newx1[,binm1[i]]~.,weights=w,family="binomial",data=pred1)) #allowing multivariate predictors
     else
       tempmodel<-summary(glm(newx1[,binm1[i]]~.,weights=w,family="binomial",data=pred2)) #allowing multivariate predictors
     med.bin[i]<-ifelse(min(tempmodel$coef[2:(nx+1),4])<alpha2,T,F)
     rela_var<-c(rela_var,name_newx[binm1[i]])
     rela_p<-rbind(rela_p,tempmodel$coef[2:(nx+1),4])
    }
  med.bin<-ifelse(med.bin+bin2>0,T,F)
  binm2<-binm1[med.bin]}
 
 catm2<-catm1
 if(length(catm1)>0) 
 {med.cat<-rep(F,length(catm1))
  for (i in 1:length(catm1))  
   {temp.p<-NULL                                 #allowing multivariate predictors
    for (j in 1:ncol(pred)) 
      if(j%in%contpred)
        temp.p<-c(temp.p,min(summary(glm(pred[,j]~newx1[,catm1[i]],weights=w))$coef[-1,4]))
      else
        temp.p<-c(temp.p,min(summary(glm(pred[,j]~newx1[,catm1[i]],weights=w,family="binomial"))$coef[-1,4]))
    med.cat[i]<-ifelse(min(temp.p)<alpha2,T,F)
    rela_var<-c(rela_var,name_newx[catm1[i]])
    rela_p<-rbind(rela_p,temp.p)
   }
  med.cat<-ifelse(med.cat+cat2>0,T,F)
  cat3<-cat2[med.cat]
  catm2<-catm1[med.cat]
  catref2<-catref1[med.cat]}

if(length(catm2)==0)
  catm2<-NULL
if(length(binm2)==0)
  binm2<-NULL
if(length(contm2)==0)
  contm2<-NULL

newx2<-newx1
temp.names=colnames(newx1)
#browser()

if(!is.null(cova))
  if(length(grep("for.m",names(cova)))!=0)
{indi=NULL
 for(i in 1:length(cova[[2]]))
  indi=c(indi,grep(cova[[2]][i],temp.names[c(contm2,binm2,catm2)]))
 if(length(indi)==0)
   cova=NULL
 else
   cova[[2]]=(temp.names[c(contm2,binm2,catm2)])[indi]
}

if (!is.null(binpred) | !is.null(catpred)) 
{newx3=newx2
 if(!is.null(catm2))
  for (i in 1:length(catm2))
    newx3[,catm2[i]]<-as.factor(newx2[,catm2[i]])
 if(!is.null(binm2))
   for (i in 1:length(binm2))
     newx3[,binm2[i]]<-as.factor(newx2[,binm2[i]]) 
 rownames(rela_p)<-rela_var
 bin.results<-list(x=newx3, dirx=pred, contm=contm2, catm=c(binm2,catm2),jointm=jointm,refy=refy,
               y=y2,y_type=y_type,fullmodel=fullmodel1,rela=rela_p,binpred=binpred,family1=family1,
               testtype=testtype,P1=P1,w=w,cova=cova,catpred=catpred,contpred=contpred)
}
else
{bin.results=NULL}

if (!is.null(contpred))
{catm<-NULL
 if(!is.null(catm2))
 {tempx<-cattobin(newx1,catm2,catref2)
  newx2<-tempx$x
  catm<-tempx$catm
  if(!is.null(binm2))
    binm2<-colnum(binm2,catm2)
  if(!is.null(contm2))
    contm2<-colnum(contm2,catm2)
  if (!is.null(jointm))
  {if (sum(cat3)==0)
    for(i in 2:(jointm[[1]]+1))
      jointm[[i]]<-colnum(jointm[[i]],catm2)
   else
     for(i in 2:(jointm[[1]]+1))
     {a<-jointm[[i]]
      b<-NULL
      for (j in a)
        if(sum(j==catm2)==0)
          b<-c(b,colnum(j,catm2))
      else for (k in 1:length(catm2))
        if (j==catm2[k])
          b<-c(b,catm[[k+1]])
      jointm[[i]]<-b}
  }
 }
 rownames(rela_p)<-rela_var
 cont.results<-list(x=newx2,dirx=pred,contm=contm2,binm=binm2,catm=catm, jointm=jointm, refy=refy, y=y2, y_type=y_type,
               fullmodel=fullmodel1,rela=rela_p,binpred=binpred,family1=family1,
               testtype=testtype,P1=P1,w=w,cova=cova, catpred=catpred,contpred=contpred)
 }
else{
  cont.results=NULL
}
results=list(bin.results=bin.results,cont.results=cont.results)
class(results)="med_iden"
 return(results)
}

summary.med_iden<-function(object,...,only=F)
{if(!is.null(object$bin.results))
  object=object$bin.results
 else
   object=object$cont.results
 
 var.name<-colnames(object$x)
 if(is.list(object$catm))                  #revised to show catm when it is a list (when x is continuous)
 {t.catm<-NULL
  for (i in 2:length(object$catm))
  t.catm<-c(t.catm,object$catm[[i]])}
 else
 {t.catm<-object$catm}
 mediator<-var.name[c(object$contm,object$binm,t.catm)]
 covariates<-var.name[-c(object$contm,object$binm,t.catm)]
 tests<-NULL
# if(object$testtype==1)
#  {for (j in 1:length(object$fullmodel))
#    tests<-cbind(tests,Anova(object$fullmodel[[j]],type="III")[,3])
#   temp<-rownames(Anova(object$fullmodel[[1]],type="III"))
   #tests<-cbind(tests,rep(NA,nrow(tests)))
# }
# else {
  tests<-object$P1 
  temp<-rownames(tests)
   #tests<-cbind(tests,rep(NA,nrow(tests)))
#   }
  rownames(tests)<-temp
  temp.name<-rownames(object$rela)
  temp2<-matrix(NA,length(temp),ncol(object$rela))
 for (i in 1:nrow(object$rela))
   temp2[grep(temp.name[i],temp),]<-object$rela[i,]
 tests<-cbind(tests,temp2)
 dimnames(tests)[[2]]<-c(paste("P-Value 1",colnames(object$y),sep="."), paste("P-Value 2", colnames(object$dirx),sep="."))
 result<-list(mediator=mediator, covariates=covariates,tests=tests, results=object,only=only)
 class(result)<-"summary.med_iden"
 result
}

print.summary.med_iden<-function(x,...)  #version 6: changed typos in the function--tests->x$tests
{cat("Identified as mediators: \n")
 print(x$mediator)
 cat("Selected as covariates: \n")
 print(x$covariates)
 cat("Tests: \n")
 temp<-rownames(x$tests)
 tests.1<-NULL
 for (z in 1:length(temp))
   if(length(grep(temp[z],x$mediator))>0)
     dimnames(x$tests)[[1]][z]<-paste(temp[z],"*")
 if (!is.null(x$results$jointm))
  {tt<-NULL
   for (i in 1:(length(x$results$jointm)-1)) 
     tt<-c(tt,x$results$jointm[[i+1]])
   tt<-unique(tt)
   for (z in 1:length(temp))
     if(length(grep(temp[z],names(x$results$x)[tt]))>0)
       dimnames(x$tests)[[1]][z]<-paste(temp[z],"-")}
 dimnames(x$tests)[[2]]<-c(paste("P-Value 1",colnames(x$results$y),sep="."), paste("P-Value 2", colnames(x$results$dirx),sep="."))
 if(!x$only)
   print(round(x$tests,3))
 else
   {temp.name<-NULL
    temp1<-rownames(x$tests)
     for (z in 1:length(temp))
     if(length(grep(temp[z],x$mediator))>0)
       {tests.1<-rbind(tests.1,x$tests[z,])
        temp.name<-c(temp.name,temp1[z])}
     else if(length(grep(temp[z],x$covariates))>0) 
       {tests.1<-rbind(tests.1,x$tests[z,])
        temp.name<-c(temp.name,temp1[z])}
    rownames(tests.1)<-temp.name
     print(round(tests.1,3))
   } 
cat("----\n *:mediator,-:joint mediator\n P-Value 1:Type-3 tests in the full model (data.org) or estimated coefficients (data.org.big) 
 when testtype=1, univariate relationship test with the outcome when testtype=2
 P-Value 2:Tests of relationship with the Predictor\n")
}

med<-function(data, x=data$bin.results$x, y=data$bin.results$y, dirx=data$bin.results$dirx, 
              binm=data$bin.results$binm,contm = data$bin.results$contm, 
              catm = data$bin.results$catm, jointm = data$bin.results$jointm, 
              cova=data$bin.results$cova, allm = c(contm, catm), 
              margin=1, n=20, nonlinear=F, df1=1, nu=0.001,D=3,distn=NULL,
              family1=data$bin.results$family1,refy=rep(0,ncol(y)),
              binpred=data$bin.results$binpred,x.new=x,pred.new=dirx, 
              cova.new=cova,type=NULL, w=NULL, w.new=NULL,xmod=NULL,custom.function=NULL)
{#for binary predictor
  med.binx<-function(data, x=data$x, y=data$y, dirx=data$dirx, dirx1=dirx, contm = data$contm, 
                     catm = data$catm, jointm = data$jointm, cova=data$cova, allm = c(contm, catm), 
                     n=20,nonlinear=F,nu=0.001,
                     D=3,distn=NULL,family1=data$family1, #
                     biny=rep(F,ncol(y)),refy=rep(0,ncol(y)),surv=rep(F,ncol(y)),type=NULL,
                     w=NULL,xmod=NULL,custom.function=NULL, full.model, best.iter1) #
  {if (is.null(allm))
    stop("Error: no potential mediator is specified")
    xnames<-colnames(x)
    pred_names<-colnames(dirx)  #
    pred_names1<-pred_names[dirx1]
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else
      cova_names=colnames(cova[[1]])}
    
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(catm))
      catm<-unlist(sapply(catm,grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    allm=c(contm,catm)
    
    te.binx<-function(full.model,new1,new0,best.iter1=NULL,surv,type)       
    {te<-NULL
    #browser()
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
      {if(is.null(type))
         type="link"
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
      else if (surv[m])
        te[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      te
    }
    
    med.binx.contm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    marg.m<-c(nom1[,med],nom0[,med])[sample(1:n3,replace=T)]
    new1<-nom1
    new1[,med]<-marg.m[1:nrow(nom1)]
    new0<-nom0
    new0[,med]<-marg.m[(nrow(nom1)+1):n3]
    if(!is.null(xmod))
    {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
    if(sum(temp.x)>0)
    {m.t=1
    m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
    m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
    for (m.t1 in temp.x)
    {new0[,m.t1]=m.t2[,m.t]
    new1[,m.t1]=m.t3[,m.t]
    m.t=m.t+1}}
    }
    dir.nom<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
        {if(is.null(type))
          type="link"
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
    else if(surv[m])
      dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    dir.nom
    }
    
    med.binx.jointm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,temp.rand,xmod,xnames)  
    {if (length(med)==1)                       #added for the new program, when there is only one mediator
    {if(is.factor(nom1[,med]))              #added to control for one factor mediator
      marg.m<-as.factor(c(as.character(nom1[,med]),as.character(nom0[,med]))[temp.rand])
    else
      marg.m<-c(nom1[,med],nom0[,med])[temp.rand]
    }        
      else                                         #added for the new program
        marg.m<-rbind(nom1[,med],nom0[,med])[temp.rand,]
      new1<-nom1
      new0<-nom0
      if(length(med)==1)                                       #added for the new program, when there is only one mediator
      {new1[,med]<-marg.m[1:nrow(new1)]                     #added for the new program 
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0))]}  #added for the new program
      else                                                     #added for the new program
      {new1[,med]<-marg.m[1:nrow(new1),]
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0)),]}
      if(!is.null(xmod))
        for (z in med)
        {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
        m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0[,m.t1]=m.t2[,m.t]
        new1[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
      dir.nom<-NULL
      for (m in 1:length(full.model))
        if(surv[m] & !is.null(best.iter1[m]))
          {if(is.null(type))
            type="link"
           dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
      else if(surv[m])
        dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      dir.nom
    }
    
    med.binx.catm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    temp.rand<-unlist(list(nom1[,med],nom0[,med]))[sample(1:n3,replace=T)]
    marg.m1<-temp.rand[1:nrow(nom1)]
    marg.m2<-temp.rand[(nrow(nom1)+1):n3]
    dir.nom<-rep(0,length(full.model))
    for (m in 1:length(full.model))
      for (i in levels(x[,med]))
      {new1<-nom1
      new1[1:dim(new1)[1],med]<-i
      new0<-nom0
      new0[1:dim(new0)[1],med]<-i
      if(!is.null(xmod))
      {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
      m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
      for (m.t1 in temp.x)
      {new0[,m.t1]=m.t2[,m.t]
      new1[,m.t1]=m.t3[,m.t]
      m.t=m.t+1}}
      }
      p<-mean(temp.rand==i,na.rm=T)
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T))}
      else if(surv[m])
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T))
      else
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T))
      }
    dir.nom
    }
    
    #1.fit the model
    
    #2. prepare for the store of results
    #set.seed(seed)
    te<-matrix(0,n,ncol(y)*length(dirx1))
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
    if(!is.null(jointm))
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))+jointm[[1]]))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")
    }
    else
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".")
    }
    denm<-rep(list(denm),length(dirx1))
    ie<-denm
    #3. repeat to get the mediation effect
    for (k in 1:n)
    {#3.1 get the te         full.model,x,y,dirx,best.iter1=NULL
      x0.temp<-apply(as.matrix(dirx[,dirx1]==1),1,sum)==0  #indicator of the reference group
      x0<-x2[x0.temp,]
      if(is.null(w))
      {w1<-NULL
      w0<-NULL}
      else
        w0<-w[x0.temp]
      for (l in 1:length(dirx1))  #l indicate the lth predictor
      {x1.2<-x2[dirx[,dirx1[l]]==1,]
      if(!is.null(w))
        w1<-w[dirx[,dirx1[l]]==1]
      #n3<-dim(x)[1] use the original size
      new1<-x1.2[sample(1:nrow(x1.2),replace=T,prob=w1),] #floor(n3/2),
      new0<-x0[sample(1:nrow(x0),replace=T,prob=w0),] #floor(n3/2),
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-te.binx(full.model,new1,new0,best.iter1,surv,type)  
      temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
      #the indirect effect of all mediators
      temp.ie<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-med.binx.jointm(full.model,new1,new0,allm,best.iter1,surv,type,temp.rand,xmod,xnames) #add temp.rand
      #new method to calculate the direct effect     
      x.temp=data.frame(x[dirx[,dirx1[l]]==1 | x0.temp,])
      new1.temp=data.frame(x.temp[temp.rand[1:nrow(x1.2)],],dirx[dirx[,dirx1[l]]==1,])
      new0.temp=data.frame(x.temp[temp.rand[(nrow(x1.2)+1):(nrow(x1.2)+nrow(x0))],],dirx[x0.temp,])
      colnames(new1.temp)<-c(xnames,pred_names)
      colnames(new0.temp)<-c(xnames,pred_names)
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names1[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0.temp,dirx[x0.temp,],inter.cov=xmod)
        m.t3=form.interaction(new1.temp,dirx[dirx[,dirx1[l]]==1,],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0.temp[,m.t1]=m.t2[,m.t]
        new1.temp[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}}
      denm[[l]][k,1:ncol(y)]<-te.binx(full.model,new1.temp,new0.temp,best.iter1,surv,type) #add temp.rand
      
      j<-2
      #3.2 mediation effect from the continuous mediator
      if (!is.null(contm))
        for (i in contm)          #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.contm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.3.mediation effect from the categorical mediator
      if (!is.null(catm))
        for (i in catm)           #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.catm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.4 mediation effect from the joint mediators
      if (!is.null(jointm))
        for (i in 1:jointm[[1]])          #full.model,x,y,med,dirx,best.iter1=NULL
        {temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
        denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.jointm(full.model,new1,new0,jointm[[i+1]],best.iter1,surv,type,temp.rand,xmod,xnames)
        j<-j+1}
      #3.5 get the indirect effects and total effect
      ie[[l]][k,]<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-denm[[l]][k,]
      ie[[l]][k,1:ncol(y)]<-temp.ie
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-denm[[l]][k,1:ncol(y)]+temp.ie
      
      if(!is.null(jointm))
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")#c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep=""))
      else
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".") #c("all",colnames(x)[c(contm,catm)])
      }
    }
    names(denm)<-pred_names1
    names(ie)<-pred_names1
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear, Survival=surv, type=type, model=full.model,best.iter=best.iter1),data=data)
    class(a)<-"med"
    return(a)
  }

#for continous predictor
  med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx, dirx1=data$contpred, binm=data$binm,contm=data$contm,
                      catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                      nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=data$family1,
                      biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx, cova.new=cova, surv=(data$y_type==4),
                      type=NULL,w=NULL, w.new=NULL, xmod=NULL,custom.function=NULL)
  {if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
    # browser()
    xnames<-colnames(x)
    pred_names<-colnames(dirx)
    ynames<-colnames(y)
    if(!is.null(cova)) {
      if(length(grep("for.m",names(cova)))==0)
        cova_names=colnames(cova)
      else 
        cova_names=colnames(cova[[1]])}
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(binm))
      binm<-unlist(sapply(binm,grep,xnames))
    if(!is.null(catm))
      for (i in 2:length(catm))
        if(is.character(catm[[i]]))
          catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    anymissing<-function(vec) #return T if there is any missing in the vec
    {if(sum(is.na(vec))>0)
      return(F)
      else return(T)
    }
    
    col_mean<-function(col,n.row,w=NULL)
    {temp<-matrix(col,n.row)
    if(is.null(w))
      return(apply(temp,1,mean,na.rm=T))
    else
      return(apply(temp,1,weighted.mean,na.rm=T,w=w))}
    
    
    dist.m.given.x<-function(x,dirx,binm=NULL,contm=NULL,catm=NULL,nonlinear,df1,w,cova) #give the model and residual of m given x
    {
      getform=function(z,nonlinear,df1)
      {if(!nonlinear)
        formu="x[,i]~."
      else
      {names.z=colnames(z)
      temp.t=unlist(lapply(z,is.character)) | unlist(lapply(z,is.factor))
      names.z1=names.z[!temp.t]
      names.z2=names.z[temp.t]
      if(length(names.z1)==0)
        formu="x[,i]~."
      else if (length(names.z2)==0)
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),sep="")
      else
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),"+",
                    paste(names.z2,collapse="+"),sep="")
      }
      formu
      }
      #browser()  
      models<-NULL
      x=data.frame(x)
      res<-NULL
      temp.namec=colnames(x)
      indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
      if(!is.null(cova))
        if(length(grep("for.m",names(cova)))!=0)
          for (i in 1:length(cova[[2]]))
            indi=c(indi,grep(cova[[2]][i],temp.namec))
      if(!is.null(catm))
      {for (i in 2:(catm$n+1))
        binm<-c(binm,catm[[i]])}
      
      z<-dirx
      z.name=paste("predictor",1:ncol(z),sep=".")
      colnames(z)=z.name
      # browser()
      if(!is.null(cova))
      {if (length(grep("for.m",names(cova)))==0)#create the predictor matrix z
        z<-cbind(z,cova)
      else 
      {
        z1<-cbind(z,cova[[1]])
        form1=getform(z1,nonlinear,df1)
      }}
      
      form0=getform(z,nonlinear,df1)
      j<-1
      
      if(!is.null(binm))
      {for(i in binm)
      {if(!i%in%indi)
      {models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=binomial(link = "logit"),weights=w)
      res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z)))}
        else
        {models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=binomial(link = "logit"),weights=w)
        res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z=z1)))}
        j<-j+1}
      }
      
      for (i in contm)
      {if(!i%in%indi)
        models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=gaussian(link="identity"),weights=w)
      else
        models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=gaussian(link="identity"),weights=w)
      res<-cbind(res,models[[j]]$res)
      j<-j+1
      }
      list(models=models,varmat=var(res,na.rm=T))
    }
    
    
    sim.xm<-function(distmgivenx,x1,dirx,binm,contm,catm,nonlinear,df1,cova)  #added nonlinear and df1 to sim.xm
    {mult.norm<-function(mu,vari,n) 
    {if (nrow(vari)!=ncol(vari)) 
      result<-c("Error: Variance matrix is not square")  
    else if (length(mu)!=nrow(vari)) 
      result<-c("Error: length mu is not right!")  
    else {   p<-length(mu)
    tmp1<-eigen(vari)$values
    tmp2<-eigen(vari)$vectors   
    result<-matrix(0,n,p)   
    for (i in 1:p)
    {result[,i]<-rnorm(n,mean=0,sd=sqrt(tmp1[i]))}   
    for (i in 1:n)
    {result[i,]<-tmp2%*%result[i,]+mu}
    }  
    result
    }
    
    
    match.margin<-function(vec)   
    {range1<-vec[1:2]
    vec1<-vec[-(1:2)]
    range2<-range(vec1,na.rm=T)
    vec1<-range1[1]+diff(range1)/diff(range2)*(vec1-range2[1])
    vec1
    }
    
    gen.mult<-function(vec)
    {if(sum(is.na(vec))>0)
      return(rep(NA,length(vec)))
      else{ 
        l<-1-sum(vec)
        l<-ifelse(l<0,0,l)
        return(rmultinom(1,size=1,prob=c(l,vec))[-1])}
    }
    
    x1=data.frame(x1)
    temp.namec=colnames(x1)
    indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
    if(!is.null(cova))
      if(length(grep("for.m",names(cova)))!=0)
        for (i in 1:length(cova[[2]]))
          indi=c(indi,grep(cova[[2]][i],temp.namec))
    
    means<-NULL
    z<-dirx
    z.name=paste("predictor",1:ncol(z),sep=".")
    colnames(z)=z.name
    
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)   #create the predictor matrix z
      z<-cbind(z,cova)
    else 
      z1<-cbind(z,cova[[1]])}
    
    binm1<-binm
    if(!is.null(catm))
    {for (i in 2:(catm$n+1))
      binm1<-c(binm1,catm[[i]])}
    if(!is.null(binm1))
      for (i in 1:length(binm1))
      {if(binm1[i]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z1)))
      else  
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z)))}
    if(!is.null(contm))
      for (i in (length(binm1)+1):length(c(binm1,contm)))
      {if(contm[i-length(binm1)]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z1)))
      else
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z)))}
    
    if(dim(means)[2]==1)                                                   #added in the new program, in case there is only one mediator
    {sim.m<-suppressWarnings(rnorm(length(means),mean=means,sd=sqrt(distmgivenx$varmat)))     #added in the new program
    sim.m2<-match.margin(c(range(means,na.rm=T),sim.m))}                          #added in the new program   
    else{
      sim.m<-t(apply(means,1,mult.norm,vari=distmgivenx$varmat,n=1))
      
      range.means<-apply(means,2,range,na.rm=T)
      
      sim.m2<-apply(rbind(range.means,sim.m),2,match.margin)    #to make the simulate fit the means' ranges
    }
    sim.m2<-data.frame(sim.m2)
    n<-dim(sim.m2)[1]
    if(!is.null(binm))
      for (i in 1:length(binm))
        sim.m2[,i]<-rbinom(n,size=1,prob=sim.m2[,i])
    
    if(!is.null(catm))
    {j<-length(binm)+1
    for (i in 2:(catm$n+1))
    {a<-sim.m2[,j:(j+length(catm[[i]])-1)]
    sim.m2[,j:(j+length(catm[[i]])-1)]<-t(apply(a,1,gen.mult))
    j<-j+length(catm[[i]])}
    }
    
    x1[,c(binm1,contm)]<-sim.m2
    
    x1
    }
    
    if(is.null(catm))
      multi=jointm
    else if(is.null(jointm))
      multi=catm
    else {temp1<-catm
    temp2<-jointm
    temp1[[1]]=catm[[1]]+jointm[[1]]
    temp2[[1]]<-NULL
    multi=append(temp1,temp2)} 
    listm=list(single=c(contm,binm),multi=multi)
    
    if (is.null(multi))                      #allm list all mediators
    {tempm<-multi
    tempm[[1]]<-NULL}
    else  tempm<-NULL
    allm<-unique(c(contm,binm,unlist(tempm)))
    nonmissing<-apply(cbind(y,x[,listm$single],dirx),1,anymissing)
    temp.name1=colnames(x)
    x<-data.frame(x[nonmissing,])
    colnames(x)=temp.name1
    y<-data.frame(y[nonmissing,])
    if(!is.null(cova))
    {cova=data.frame(cova[nonmissing,])
    colnames(cova)=cova_names}
    colnames(y)<-ynames
    pred<-data.frame(dirx[nonmissing,])
    pred1<-data.frame(dirx[nonmissing, dirx1])
    colnames(pred)<-pred_names
    colnames(pred1)<-pred_names[dirx1]
    w<-w[nonmissing]
    nonmissing1<-apply(cbind(x.new[,listm$single],pred.new),1,anymissing)
    temp.name1=colnames(x.new)
    x.new<-data.frame(x.new[nonmissing1,])
    colnames(x.new)=temp.name1
    w.new<-w.new[nonmissing1]
    pred.new<-data.frame(pred.new[nonmissing1,])
    pred.new1<-data.frame(pred.new[nonmissing1,dirx1])
    colnames(pred.new)<-pred_names
    colnames(pred.new1)<-pred_names[dirx1]
    if(!is.null(cova.new))  
    {cova.new=data.frame(cova.new[nonmissing,])
    colnames(cova.new)=cova_names}
    
    #1.fit the model
    x2<-cbind(x,pred)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    for(j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      
      if(!is.null(custom.function))
      { if(!is.na(custom.function[j]))
      {cf1=gsub("responseY","y[,j]",custom.function[j])
      cf1=gsub("dataset123","x2",cf1)
      cf1=gsub("weights123","w",cf1)
      full.model[[j]]<-eval(parse(text=cf1))}
        else if(nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                   distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
        }
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
        else
          full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
        }
      }
      else if(nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                 distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
      }
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
      else
        full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    n.new<-nrow(x.new)
    
    #3. get the joint distribution of m given x

    distmgivenx<-dist.m.given.x(x,pred,binm,contm,catm,nonlinear,df1,w,cova)
    te1.0<-NULL
    denm1.0<-NULL
    denm1.1<-NULL
    n1<-dim(x)[1]
    
    #4. repeat to get the mediation effect
    for (l in 1:length(dirx1)) {
      denm1<-NULL
      denm1.2=NULL
      te1<-NULL
      for (k in 1:n)
      {new0<-sim.xm(distmgivenx,x.new,pred.new,binm,contm,catm,nonlinear,df1,cova.new) #draw ms conditional on x.new
      temp.pred<-pred.new
      temp.pred[,l]<-temp.pred[,dirx1[l]]+margin
      if(!is.null(xmod))   #allows the interaction of pred with xmod
      {cova.new1=cova.new
      x.new1=x.new
      if(!is.null(cova.new))
      {temp.cova=intersect(grep(pred_names[dirx1[l]],cova_names),grep(xmod,cova_names))
      if(sum(temp.cova)>0)
      {m.t=1
      m.t2=form.interaction(cova.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.cova)
      {cova.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}
      }}
      temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(x.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.x)
      {x.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}}
      new1<-sim.xm(distmgivenx,x.new1,temp.pred,binm,contm,catm,nonlinear,df1,cova.new1)  #draw from the conditional distribution of m given x
      }
      else
        new1<-sim.xm(distmgivenx,x.new,temp.pred,binm,contm,catm,nonlinear,df1,cova.new)  #draw from the conditional distribution of m given x
      new1<-cbind(new1,temp.pred)   #draw ms conditional on x.new+margin
      new0<-cbind(new0,pred.new) 
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      denm2<-NULL
      
      #browser()   
      
      sample.temp<-sample(1:n.new,2*n.new,replace = T,prob=w.new)   #random sample from the original data
      
      #4.0.0 get the total indirect effect
      temp.new1<-new1
      temp.new1[,allm]<-x.new[sample.temp[1:n.new],allm]
      temp.new0<-new0
      temp.new0[,allm]<-x.new[sample.temp[(n.new+1):(2*n.new)],allm]
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(x.new[sample.temp[1:n.new],],x.new[sample.temp[1:n.new],z],inter.cov=xmod)
          m.t3=form.interaction(x.new[sample.temp[(n.new+1):(2*n.new)],],x.new[sample.temp[(n.new+1):(2*n.new)],z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {temp.new1[,m.t1]=m.t2[,m.t]
          temp.new0[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          {if(is.null(type))
            type="link"
           denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin}
      else if(surv[m])
        denm3<-(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin
      else
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin
      
      #4.0 get the direct effect
      temp.new1<-x.new[sample.temp[1:n.new],]
      temp.new1=cbind(temp.new1,temp.pred)
      temp.new0<-x.new[sample.temp[(n.new+1):(2*n.new)],]
      temp.new0=cbind(temp.new0,pred.new)
      colnames(temp.new1)<-c(xnames,pred_names)
      colnames(temp.new0)<-c(xnames,pred_names)
      
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(temp.new1,temp.pred[,dirx1[l]],inter.cov=xmod)
        m.t3=form.interaction(temp.new0,pred.new[,dirx1[l]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {temp.new1[,m.t1]=m.t2[,m.t]
        temp.new0[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
      }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin)
      else
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin)
      
      #4.1 get the te
      te0<-NULL
      for(m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m],type=type)-predict(full.model[[m]],new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        te0<-c(te0, (predict(full.model[[m]],new1,type=type)-predict(full.model[[m]],new0,type=type))/margin)
      else
        te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m])-predict(full.model[[m]],new0,best.iter1[m]))/margin)
      te1<-cbind(te1,te0)
      
      #4.2 mediation effect from the single mediator
      # browser()
      if (!is.null(listm$single))
        for (i in 1:length(listm$single))
        {new1.nm<-new1
        new0.nm<-new0
        temp.m<-x.new[sample.temp,listm$single[i]]
        new1.nm[,listm$single[i]]<-temp.m[1:n.new]    #draw m from its original distribution
        new0.nm[,listm$single[i]]<-temp.m[(n.new+1):(2*n.new)]    #draw m from its original distribution
        
        if(!is.null(xmod))
        {temp.x=intersect(grep(xnames[listm$single[i]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new1.nm,new1.nm[,listm$single[i]],inter.cov=xmod)
        m.t3=form.interaction(new0.nm,new0.nm[,listm$single[i]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new1.nm[,m.t1]=m.t2[,m.t]
        new0.nm[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
       
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      
      #4.3.mediation effect from the joint mediator
      if (!is.null(listm$multi))
        for (i in 2:(listm$multi[[1]]+1))
        {new1.nm<-new1
        new0.nm<-new0
        new1.nm[,listm$multi[[i]]]<-x.new[sample.temp[1:n.new],listm$multi[[i]]]    #draw m from its original distribution
        new0.nm[,listm$multi[[i]]]<-x.new[sample.temp[(n.new+1):(2*n.new)],listm$multi[[i]]]    #draw m from its original distribution
        
        if(!is.null(xmod))
          for (z in listm$multi[[i]])
          {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new1.nm,new1.nm[,z],inter.cov=xmod)
          m.t3=form.interaction(new0.nm,new0.nm[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new1.nm[,m.t1]=m.t2[,m.t]
          new0.nm[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
          }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            {if(is.null(type))
              type="link"
             denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)}
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      denm1<-rbind(denm1,denm2)
      denm1.2=rbind(denm1.2,as.matrix(denm3))
      }
      denm1.0[[l]]<-denm1 
      denm1.1[[l]]<-denm1.2 
      te1.0[[l]]<-te1
    } 
    
    #4.4 get the indirect effects
    denm<-NULL
    denm1<-NULL
    te<-NULL
    ie<-NULL
    for (l in 1:length(dirx1))
    {denm[[l]]<-apply(denm1.0[[l]],2,col_mean,n.new)
    denm1[[l]]<-apply(denm1.1[[l]],2,col_mean,n.new)
    te0<-matrix(apply(te1.0[[l]],1,mean),n.new)
    #te<-cbind(te,te0)
    temp1<-ncol(denm[[l]])/ncol(te0)
    temp2<-NULL
    for(temp in 1:temp1)
      temp2<-cbind(temp2,te0)
    ie[[l]]<-temp2-denm[[l]]
    ie[[l]][,1:ncol(y)]=matrix(rep(te0,ncol(y)),ncol=ncol(y))-denm1[[l]]      #the total indirect effect
    te=cbind(te,ie[[l]][,1:ncol(y)]+denm[[l]][,1:ncol(y)])                    #the total effect
    if(!is.null(listm$multi)) 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    if(!is.null(listm$multi))
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    }
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
    names(denm)<-pred_names[dirx1]
    names(ie)<-pred_names[dirx1]
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear,Survival=surv, type=type, model=full.model,best.iter=best.iter1),pred.new=pred.new,w.new=w.new,data=data,distmgivenx=distmgivenx)
    class(a)<-"med"
    return(a)
  }
 
 anymissing<-function(vec) #return T if there is any missing in the vec
 {if(sum(is.na(vec))>0)
   return(F)
   else return(T)
 }


 if(is.null(data)){
   surv=rep(F,ncol(y))
   biny=rep(F,ncol(y))
   if(is.null(distn))
     distn<-rep(NA,ncol(y))
   for(j in 1:ncol(y)) {
     if(class(y[,j])=="Surv"){
       surv[j]=T
       if(is.na(distn[j]))
         distn[j]="coxph"
       if(is.null(type) & nonlinear)
         type="response"
       else if (is.null(type))
         type="risk"
     }
     else if(is.character(y[,j]) | is.factor(y[,j]) | nlevels(as.factor(y[,j]))==2)
     {biny[j]=T
     if(is.na(family1[[j]]))
       family1[[j]] = binomial("logit")
     if(is.na(distn[j]))
       distn[j]="bernoulli" 
     if(!is.na(refy[j]))
       y[,j]<-ifelse(y[,j]==refy[j],0,1)
     else
       y[,j]<-ifelse(as.factor(y[,j])==levels(as.factor(y[,j]))[1],0,1)
     }
     else { 
       if(is.na(family1[[j]]))
         family1[[j]] = gaussian(link = "identity")
       if(is.na(distn[j]))
         distn[j]="gaussian" 
     }
   }
#   data=data.org(x=x,y=y,pred=pred,mediator=mediator,contmed=contmed,binmed=binmed,binref=binref,catmed=catmed,
#                 catref=catref,jointm=jointm,refy=refy, 
#                 family1=family1,
#                 predref=predref,alpha=alpha,alpha2=alpha2,testtype=testtype, w=w,cova=cova)
 }
 else
 {
 if(is.null(data$bin.results))
   {y=data$cont.results$y
    y_type=data$cont.results$y_type
    binpred=NULL
    catpred=NULL
    contpred=data$cont.results$contpred}
 else 
   {y=data$bin.results$y
   y_type=data$bin.results$y_type
   binpred=data$bin.results$binpred
   catpred=data$bin.results$catpred
   contpred=data$bin.results$contpred}
 biny=(y_type==2)
 surv=(y_type==4)
 if(sum(surv)>0 & is.null(y_type) & nonlinear)
   type="response"
 else if (sum(surv)>0 & is.null(y_type))
   type="risk"
 if(is.null(distn))
   distn<-rep(NA,ncol(y))
 distn[is.na(distn) & y_type==2]="bernoulli"
 distn[is.na(distn) & y_type==4]="coxph"
 distn[is.na(distn) & y_type==1]="gaussian"
 }

 a.binx<-NULL
 a.contx<-NULL
 if(!(is.null(binpred) & is.null(catpred))){
 if(!is.null(data$bin.results)) {
   data2=data$bin.results
   x=data2$x
   y=data2$y
   dirx=data2$dirx
   binm=data2$binm
   contm = data2$contm
   catm = data2$catm
   jointm = data2$jointm
   cova=data2$cova
   allm = c(contm, catm)
   family1=data2$family1
   binpred=data2$binpred
   catpred=data2$catpred}

   if (is.null(c(binm,contm,catm)))
     stop("Error: no potential mediator is specified")
   
   xnames<-colnames(x)
   pred_names<-colnames(dirx)
   ynames<-colnames(y)
   if(!is.null(cova)) {
     if(length(grep("for.m",names(cova)))==0)
       cova_names=colnames(cova)
     else 
       cova_names=colnames(cova[[1]])}
   if(is.character(contm))
     contm<-unlist(sapply(contm,grep,xnames))
   if(is.character(binm))
     binm<-unlist(sapply(binm,grep,xnames))
   
   #1.fit the model
   x2<-cbind(x,dirx)
   colnames(x2)<-c(xnames,pred_names)
   full.model<-NULL
   best.iter1<-NULL

   for (j in 1:ncol(y)){
     if(biny[j])                     #recode y if y is binary
       y[,j]<-ifelse(y[,j]==refy[j],0,1)
     x1<-x2[!is.na(y[,j]),]             #delete nas in y for mart
     y1<-y[!is.na(y[,j]),j]
     w1<-w[!is.na(y[,j])]
     if(!is.null(custom.function)){
       if(!is.na(custom.function[j])){
         cf1=gsub("responseY","y1",custom.function[j])
         cf1=gsub("dataset123","x1",cf1)
         cf1=gsub("weights123","w1",cf1)
         full.model[[j]]<-eval(parse(text=cf1))
       }
       else if (nonlinear)
       {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                  distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
       best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
       while(full.model[[j]]$n.trees-best.iter1[j]<30){
         full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
         best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
       else
       {if(surv[j])
         full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
       else
         full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
       }
     }
     else if (nonlinear)
     {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
     best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
     while(full.model[[j]]$n.trees-best.iter1[j]<30){
       full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
       best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
     else
     {if(surv[j])
       full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
     else
       full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
     }
   }
   
   
   if(!is.null(data$bin.results$binpred))
     for(i in data$bin.results$binpred)
     {if(is.null(a.binx))
       a.binx<-med.binx(data=data$bin.results, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                        catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                        nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                        biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                        custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     else
     {a<-med.binx(data=data$bin.results, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                  catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                  nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                  biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                  custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     a.binx$te=cbind(a.binx$te,a$te)
     a.binx$denm=list(a.binx$denm,a$denm)
     a.binx$ie=list(a.binx$ie,a$ie)}
     }
   
   if(!is.null(data$bin.results$catpred))
     for(i in 1:length(data$bin.results$catpred))
     {if(is.null(a.binx))
       a.binx<-med.binx(data=data$bin.results, x=x, y=y, dirx=dirx, dirx1=data$bin.results$catpred[[i]], contm = contm, 
                        catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                        nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                        biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                        custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     else
     {a<-med.binx(data=data$bin.results, x=x, y=y, dirx=dirx, dirx1=data$bin.results$catpred[[i]], contm = contm, 
                  catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                  nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                  biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                  custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     a.binx$te=cbind(a.binx$te,a$te)
     a.binx$denm=list(a.binx$denm,a$denm)
     a.binx$ie=list(a.binx$ie,a$ie)}
     }
 
 }
 
 if(!is.null(contpred)){
  if(!is.null(data$cont.results)){
   data2=data$cont.results
   x=data2$x
   y=data2$y
   dirx=data2$dirx
   binm=data2$binm
   contm = data2$contm
   catm = data2$catm
   jointm = data2$jointm
   cova=data2$cova
   allm = c(contm, catm)
   family1=data2$family1
   binpred=data2$binpred
   if(is.null(x.new))
   x.new=x
   if(is.null(pred.new))
   pred.new=dirx 
   if(is.null(cova.new))
   cova.new=cova}
     
   if (is.null(c(binm,contm,catm)))
     stop("Error: no potential mediator is specified")

   a.contx<-med.contx(data=data$cont.results,x=x,y=y,dirx=dirx,dirx1=data$cont.results$contpred,binm=binm,contm=contm,
                      catm=catm, jointm=jointm,cova=cova, margin=margin, n=n,  
                      nonlinear=nonlinear, df1=df1, nu=nu,D=D, distn=distn, 
                      family1=family1,biny=biny,refy=refy,x.new=x.new,pred.new=pred.new,
                      cova.new=cova.new,surv=surv,type=type,w,w.new,xmod=xmod,
                      custom.function=custom.function)
 }
 
 a<-list(a.binx=a.binx, a.contx=a.contx)
 class(a)<-"med"
 return(a)
}
  

print.med<-function(x,...,digit=4)
{if(!is.null(x$a.bin)){
  x1=x$a.bin
 for(l in 1:length(x1$ie))
 {cat("\n\nFor the predictor",names(x1$ie)[l],":\n")
  cat(" The estimated total effect:")
  if(is.null(x1$w.new))
    print(mean(x1$te[,l],na.rm=T),digit)
  else
    print(round(weighted.mean(x1$te[,l],na.rm=T,w=x1$w.new),digit))
  cat("\n The estimated indirect effect:\n")
  if(is.null(x1$w.new))
     print(round(apply(x1$ie[[l]],2,mean,na.rm=T),digit))
  else
     print(round(apply(x1$ie[[l]],2,weighted.mean,na.rm=T,w=x1$w.new),digit))}}
  if(!is.null(x$a.cont)){
    x1=x$a.cont
    for(l in 1:length(x1$ie))
    {cat("\n\nFor the predictor",names(x1$ie)[l],":\n")
      cat(" The estimated total effect:")
      if(is.null(x1$w.new))
        print(mean(x1$te[,l],na.rm=T),digit)
      else
        print(round(weighted.mean(x1$te[,l],na.rm=T,w=x1$w.new),digit))
      cat("\n The estimated indirect effect:\n")
      if(is.null(x1$w.new))
        print(round(apply(x1$ie[[l]],2,mean,na.rm=T),digit))
      else
        print(round(apply(x1$ie[[l]],2,weighted.mean,na.rm=T,w=x1$w.new),digit))}}
}


boot.med<-function(data,x=data$x, y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,catm=data$catm,
                   jointm=data$jointm, cova=data$cova, margin=1,n=20,nonlinear=F,df1=1,nu=0.001,
                   D=3,distn=NULL,family1=data$family1,n2=50,w=rep(1,nrow(x)),refy=NULL,x.new=x,
                   pred.new=dirx,cova.new=cova,binpred=data$binpred,type=NULL,w.new=NULL,
                   all.model=FALSE,xmod=NULL,custom.function=NULL)
{boot.med.binx<-function(data,x=data$x, y=data$y,dirx=data$dirx,contm=data$contm,catm=data$catm,
                         jointm=data$jointm, cova=data$cova,n=20,n2=50,nonlinear=F,nu=0.001,binpred=data$binpred,catpred=data$catpred,
                         D=3,distn="bernoulli",family1=binomial("logit"),w=rep(1,nrow(x)),biny=(data$y_type==2),
                         refy=rep(NA,ncol(y)),surv=(data$y_type==4),type,all.model=FALSE,xmod=NULL,custom.function=NULL)
  #n2 is the time of bootstrap
{
  med.binx<-function(data, x=data$x, y=data$y, dirx=data$dirx, dirx1=dirx, contm = data$contm, 
                     catm = data$catm, jointm = data$jointm, cova=data$cova, allm = c(contm, catm), 
                     n=20,nonlinear=F,nu=0.001,
                     D=3,distn=NULL,family1=data$family1, #
                     biny=rep(F,ncol(y)),refy=rep(0,ncol(y)),surv=rep(F,ncol(y)),type=NULL,
                     w=NULL,xmod=NULL,custom.function=NULL, full.model, best.iter1) #
  {if (is.null(allm))
    stop("Error: no potential mediator is specified")
    xnames<-colnames(x)
    pred_names<-colnames(dirx)  #
    pred_names1<-pred_names[dirx1]
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else
      cova_names=colnames(cova[[1]])}
    
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(catm))
      catm<-unlist(sapply(catm,grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    allm=c(contm,catm)
    
    te.binx<-function(full.model,new1,new0,best.iter1=NULL,surv,type)       
    {te<-NULL
    #browser()
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
      else if (surv[m])
        te[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      te
    }
    
    med.binx.contm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    marg.m<-c(nom1[,med],nom0[,med])[sample(1:n3,replace=T)]
    new1<-nom1
    new1[,med]<-marg.m[1:nrow(nom1)]
    new0<-nom0
    new0[,med]<-marg.m[(nrow(nom1)+1):n3]
    if(!is.null(xmod))
    {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
    if(sum(temp.x)>0)
    {m.t=1
    m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
    m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
    for (m.t1 in temp.x)
    {new0[,m.t1]=m.t2[,m.t]
    new1[,m.t1]=m.t3[,m.t]
    m.t=m.t+1}}
    }
    dir.nom<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
    else if(surv[m])
      dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    dir.nom
    }
    
    med.binx.jointm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,temp.rand,xmod,xnames)  
    {if (length(med)==1)                       #added for the new program, when there is only one mediator
    {if(is.factor(nom1[,med]))              #added to control for one factor mediator
      marg.m<-as.factor(c(as.character(nom1[,med]),as.character(nom0[,med]))[temp.rand])
    else
      marg.m<-c(nom1[,med],nom0[,med])[temp.rand]
    }        
      else                                         #added for the new program
        marg.m<-rbind(nom1[,med],nom0[,med])[temp.rand,]
      new1<-nom1
      new0<-nom0
      if(length(med)==1)                                       #added for the new program, when there is only one mediator
      {new1[,med]<-marg.m[1:nrow(new1)]                     #added for the new program 
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0))]}  #added for the new program
      else                                                     #added for the new program
      {new1[,med]<-marg.m[1:nrow(new1),]
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0)),]}
      if(!is.null(xmod))
        for (z in med)
        {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
        m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0[,m.t1]=m.t2[,m.t]
        new1[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
      dir.nom<-NULL
      for (m in 1:length(full.model))
        if(surv[m] & !is.null(best.iter1[m])){
          if(is.null(type))
            type="link"
          dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
      else if(surv[m])
        dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      dir.nom
    }
    
    med.binx.catm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    temp.rand<-unlist(list(nom1[,med],nom0[,med]))[sample(1:n3,replace=T)]
    marg.m1<-temp.rand[1:nrow(nom1)]
    marg.m2<-temp.rand[(nrow(nom1)+1):n3]
    dir.nom<-rep(0,length(full.model))
    for (m in 1:length(full.model))
      for (i in levels(x[,med]))
      {new1<-nom1
      new1[1:dim(new1)[1],med]<-i
      new0<-nom0
      new0[1:dim(new0)[1],med]<-i
      if(!is.null(xmod))
      {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
      m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
      for (m.t1 in temp.x)
      {new0[,m.t1]=m.t2[,m.t]
      new1[,m.t1]=m.t3[,m.t]
      m.t=m.t+1}}
      }
      p<-mean(temp.rand==i,na.rm=T)
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T))}
      else if(surv[m])
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T))
      else
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T))
      }
    dir.nom
    }
    
    #1.fit the model
   
    #2. prepare for the store of results
    #set.seed(seed)
    te<-matrix(0,n,ncol(y)*length(dirx1))
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
    if(!is.null(jointm))
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))+jointm[[1]]))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")
    }
    else
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".")
    }
    denm<-rep(list(denm),length(dirx1))
    ie<-denm
    #3. repeat to get the mediation effect
    for (k in 1:n)
    {#3.1 get the te         full.model,x,y,dirx,best.iter1=NULL
      x0.temp<-apply(as.matrix(dirx[,dirx1]==1),1,sum)==0  #indicator of the reference group
      x0<-x2[x0.temp,]
      if(is.null(w))
      {w1<-NULL
      w0<-NULL}
      else
        w0<-w[x0.temp]
      for (l in 1:length(dirx1))  #l indicate the lth predictor
      {x1.2<-x2[dirx[,dirx1[l]]==1,]
      if(!is.null(w))
        w1<-w[dirx[,dirx1[l]]==1]
      #n3<-dim(x)[1] use the original size
      new1<-x1.2[sample(1:nrow(x1.2),replace=T,prob=w1),] #floor(n3/2),
      new0<-x0[sample(1:nrow(x0),replace=T,prob=w0),] #floor(n3/2),
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-te.binx(full.model,new1,new0,best.iter1,surv,type)  
      temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
      #the indirect effect of all mediators
      temp.ie<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-med.binx.jointm(full.model,new1,new0,allm,best.iter1,surv,type,temp.rand,xmod,xnames) #add temp.rand
      #new method to calculate the direct effect     
       x.temp=data.frame(x[dirx[,dirx1[l]]==1 | x0.temp,])
      new1.temp=data.frame(x.temp[temp.rand[1:nrow(x1.2)],],dirx[dirx[,dirx1[l]]==1,])
      new0.temp=data.frame(x.temp[temp.rand[(nrow(x1.2)+1):(nrow(x1.2)+nrow(x0))],],dirx[x0.temp,])
      colnames(new1.temp)<-c(xnames,pred_names)
      colnames(new0.temp)<-c(xnames,pred_names)
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names1[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0.temp,dirx[x0.temp,],inter.cov=xmod)
        m.t3=form.interaction(new1.temp,dirx[dirx[,dirx1[l]]==1,],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0.temp[,m.t1]=m.t2[,m.t]
        new1.temp[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}}
      denm[[l]][k,1:ncol(y)]<-te.binx(full.model,new1.temp,new0.temp,best.iter1,surv,type) #add temp.rand
      
      j<-2
      #3.2 mediation effect from the continuous mediator
      if (!is.null(contm))
        for (i in contm)          #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.contm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.3.mediation effect from the categorical mediator
      if (!is.null(catm))
        for (i in catm)           #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.catm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.4 mediation effect from the joint mediators
      if (!is.null(jointm))
        for (i in 1:jointm[[1]])          #full.model,x,y,med,dirx,best.iter1=NULL
        {temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
        denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.jointm(full.model,new1,new0,jointm[[i+1]],best.iter1,surv,type,temp.rand,xmod,xnames)
        j<-j+1}
      #3.5 get the indirect effects and total effect
      ie[[l]][k,]<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-denm[[l]][k,]
      ie[[l]][k,1:ncol(y)]<-temp.ie
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-denm[[l]][k,1:ncol(y)]+temp.ie
      
      if(!is.null(jointm))
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")#c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep=""))
      else
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".") #c("all",colnames(x)[c(contm,catm)])
      }
    }
    names(denm)<-pred_names1
    names(ie)<-pred_names1
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear, Survival=surv, type=type, model=full.model,best.iter=best.iter1),data=data)
    #class(a)<-"med"
    return(a)
  }
  
  if (is.null(c(contm,catm)))
    stop("Error: no potential mediator is specified")
 
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  pred_names1<-pred_names[c(binpred,unlist(catpred))]
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
     cova_names=colnames(cova)
    else 
     cova_names=colnames(cova[[1]])}
  ynames=colnames(y)
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(catm))
    catm<-unlist(sapply(catm,grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  #set.seed(seed)
  allm=c(contm,catm)
  ny=ncol(y)
  nx=length(binpred)+length(unlist(catpred))
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  if(is.null(jointm))
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))))
   ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))))
   dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
   colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
   rownames(ie1)<-pred_names1}
  else 
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))+jointm[[1]]))
   dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
   ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))+jointm[[1]]))
   dimnames(ie1)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
   rownames(ie1)<-pred_names1}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names1
  
  #1.fit the model
  x2<-cbind(x,dirx)
  colnames(x2)<-c(xnames,pred_names)
  full.model<-NULL
  best.iter1<-NULL
  
  for (j in 1:ncol(y)){
    if(biny[j])                     #recode y if y is binary
      y[,j]<-ifelse(y[,j]==refy[j],0,1)
    x1<-x2[!is.na(y[,j]),]             #delete nas in y for mart
    y1<-y[!is.na(y[,j]),j]
    w1<-w[!is.na(y[,j])]
    if(!is.null(custom.function)){
      if(!is.na(custom.function[j])){
        cf1=gsub("responseY","y1",custom.function[j])
        cf1=gsub("dataset123","x1",cf1)
        cf1=gsub("weights123","w1",cf1)
        full.model[[j]]<-eval(parse(text=cf1))
      }
      else if (nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                 distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
      else
        full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
      }
    }
    else if (nonlinear)
    {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                               distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
    best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
    while(full.model[[j]]$n.trees-best.iter1[j]<30){
      full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
    else
    {if(surv[j])
      full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
    else
      full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
    }
  }
  
  a.binx<-NULL
  if(!is.null(binpred))
    for(i in binpred)
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  
  if(!is.null(catpred))
    for(i in 1:length(catpred))
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=catpred[[i]], contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=catpred[[i]], contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  
  #temp<-med.binx(data=NULL,x,y,dirx,contm,catm,jointm,cova,allm,n,nonlinear,nu,D,distn,family1,
  #               biny,refy,surv,type,w=w,xmod,custom.function=custom.function)
  temp=a.binx
  te[1,]<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
   ie1[l,]<-apply(temp$ie[[l]],2,mean)}  #first row is the estimated value
  de[1,]<-apply(temp.1,2,mean,na.rm=T)
  model<-temp$model
  all_model=NULL #to store all fitted models if all.model is TRUE
  all_iter=NULL
  all_boot=NULL
  
  for (t.i in 1:n2)
  {boots<-sample(1:nrow(x),replace=T,prob=w)
   x.temp<-data.frame(x[boots,])
   names(x.temp)=xnames
   y.temp<-data.frame(y[boots,])
   colnames(y.temp)=ynames
   pred.temp<-data.frame(dirx[boots,])
   colnames(pred.temp)=pred_names
   w1=NULL
   
   #1.fit the model
   x2<-cbind(x.temp,pred.temp)
   colnames(x2)<-c(xnames,pred_names)
   full.model<-NULL
   best.iter1<-NULL
   
   for (j in 1:ncol(y.temp)){
     if(biny[j])                     #recode y if y is binary
       y.temp[,j]<-ifelse(y.temp[,j]==refy[j],0,1)
     x1<-x2[!is.na(y.temp[,j]),]             #delete nas in y for mart
     y1<-y.temp[!is.na(y.temp[,j]),j]
     w1<-w[!is.na(y.temp[,j])]
     if(!is.null(custom.function)){
       if(!is.na(custom.function[j])){
         cf1=gsub("responseY","y1",custom.function[j])
         cf1=gsub("dataset123","x1",cf1)
         cf1=gsub("weights123","w1",cf1)
         full.model[[j]]<-eval(parse(text=cf1))
       }
       else if (nonlinear)
       {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                  distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
       best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
       while(full.model[[j]]$n.trees-best.iter1[j]<30){
         full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
         best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
       else
       {if(surv[j])
         full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
       else
         full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
       }
     }
     else if (nonlinear)
     {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
     best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
     while(full.model[[j]]$n.trees-best.iter1[j]<30){
       full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
       best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
     else
     {if(surv[j])
       full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
     else
       full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
     }
   }
   
   a.binx<-NULL
   if(!is.null(binpred))
     for(i in binpred)
     {if(is.null(a.binx))
       a.binx<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=i, contm = contm, 
                        catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                        nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                        biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                        custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     else
     {a<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=i, contm = contm, 
                  catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                  nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                  biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                  custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     a.binx$te=cbind(a.binx$te,a$te)
     a.binx$denm=list(a.binx$denm,a$denm)
     a.binx$ie=list(a.binx$ie,a$ie)}
     }
   
   if(!is.null(catpred))
     for(i in 1:length(catpred))
     {if(is.null(a.binx))
       a.binx<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=catpred[[i]], contm = contm, 
                        catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                        nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                        biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                        custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     else
     {a<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=catpred[[i]], contm = contm, 
                  catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                  nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                  biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                  custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
     a.binx$te=cbind(a.binx$te,a$te)
     a.binx$denm=list(a.binx$denm,a$denm)
     a.binx$ie=list(a.binx$ie,a$ie)}
     }
   temp=a.binx
   #temp<-med.binx(data=NULL,x=x1, y=y1, dirx=pred1, contm=contm, catm=catm,jointm=jointm,cova=cova,allm=allm,n=n,
   #                nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,biny=biny,refy=refy,surv=surv,type=type,w=NULL,
   #               xmod=xmod,custom.function = custom.function)
   if(all.model)
     {all_model[[t.i]]=temp$model$model
      all_iter=rbind(all_iter,temp$model$best.iter)
      all_boot=rbind(all_boot,boots)}
   te[1+t.i,]<-apply(temp$te,2,mean,na.rm=T)
   temp.1<-NULL
   for (l in 1:nx)
   {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
    ie[[l]][t.i,]<-apply(temp$ie[[l]],2,mean,na.rm=T)}  #first row is the estimated value
   de[1+t.i,]<-apply(temp.1,2,mean,na.rm=T)
   print(t.i)
  }
  
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model, 
          data=list(x=x,y=y,dirx=dirx,contm=contm,catm=catm,jointm=jointm,binpred=binpred,contpred=NULL,catpred=catpred),
          all_model=all_model,all_iter=all_iter,all_boot=all_boot,mod=F)
  class(a)<-"mma"
  return(a)
}

boot.med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,dirx1=data$contpred,binm=data$binm,contm=data$contm,
                         catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                         nonlinear=F,df1=1,nu=0.001,D=3,distn="gaussian",
                         family1=gaussian(link="identity"),n2=50,w=rep(1,nrow(x)),
                         biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx,
                         cova.new=cova,surv,type,w.new=NULL,all.model=all.model,xmod=NULL,
                         custom.function = custom.function)
{
  med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx, dirx1=data$contpred, binm=data$binm,contm=data$contm,
                      catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                      nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=data$family1,
                      biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx, cova.new=cova, surv=(data$y_type==4),
                      type=NULL,w=NULL, w.new=NULL, xmod=NULL,custom.function=NULL)
  {if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
    # browser()
    xnames<-colnames(x)
    pred_names<-colnames(dirx)
    ynames<-colnames(y)
    if(!is.null(cova)) {
      if(length(grep("for.m",names(cova)))==0)
        cova_names=colnames(cova)
      else 
        cova_names=colnames(cova[[1]])}
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(binm))
      binm<-unlist(sapply(binm,grep,xnames))
    if(!is.null(catm))
      for (i in 2:length(catm))
        if(is.character(catm[[i]]))
          catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    anymissing<-function(vec) #return T if there is any missing in the vec
    {if(sum(is.na(vec))>0)
      return(F)
      else return(T)
    }
    
    col_mean<-function(col,n.row,w=NULL)
    {temp<-matrix(col,n.row)
    if(is.null(w))
      return(apply(temp,1,mean,na.rm=T))
    else
      return(apply(temp,1,weighted.mean,na.rm=T,w=w))}
    
    
    dist.m.given.x<-function(x,dirx,binm=NULL,contm=NULL,catm=NULL,nonlinear,df1,w,cova) #give the model and residual of m given x
    {
      getform=function(z,nonlinear,df1)
      {if(!nonlinear)
        formu="x[,i]~."
      else
      {names.z=colnames(z)
      temp.t=unlist(lapply(z,is.character)) | unlist(lapply(z,is.factor))
      names.z1=names.z[!temp.t]
      names.z2=names.z[temp.t]
      if(length(names.z1)==0)
        formu="x[,i]~."
      else if (length(names.z2)==0)
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),sep="")
      else
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),"+",
                    paste(names.z2,collapse="+"),sep="")
      }
      formu
      }
      #browser()  
      models<-NULL
      x=data.frame(x)
      res<-NULL
      temp.namec=colnames(x)
      indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
      if(!is.null(cova))
        if(length(grep("for.m",names(cova)))!=0)
          for (i in 1:length(cova[[2]]))
            indi=c(indi,grep(cova[[2]][i],temp.namec))
      if(!is.null(catm))
      {for (i in 2:(catm$n+1))
        binm<-c(binm,catm[[i]])}
      
      z<-dirx
      z.name=paste("predictor",1:ncol(z),sep=".")
      colnames(z)=z.name
      # browser()
      if(!is.null(cova))
      {if (length(grep("for.m",names(cova)))==0)#create the predictor matrix z
        z<-cbind(z,cova)
      else 
      {
        z1<-cbind(z,cova[[1]])
        form1=getform(z1,nonlinear,df1)
      }}
      
      form0=getform(z,nonlinear,df1)
      j<-1
      
      if(!is.null(binm))
      {for(i in binm)
      {if(!i%in%indi)
      {models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=binomial(link = "logit"),weights=w)
      res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z)))}
        else
        {models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=binomial(link = "logit"),weights=w)
        res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z1)))}
        j<-j+1}
      }
      # browser()
      for (i in contm)
      {if(!i%in%indi)
        models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=gaussian(link="identity"),weights=w)
      else
        models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=gaussian(link="identity"),weights=w)
      res<-cbind(res,models[[j]]$res)
      j<-j+1
      }
      list(models=models,varmat=var(res))
    }
    
    
    sim.xm<-function(distmgivenx,x1,dirx,binm,contm,catm,nonlinear,df1,cova)  #added nonlinear and df1 to sim.xm
    {mult.norm<-function(mu,vari,n) 
    {if (nrow(vari)!=ncol(vari)) 
      result<-c("Error: Variance matrix is not square")  
    else if (length(mu)!=nrow(vari)) 
      result<-c("Error: length mu is not right!")  
    else {   p<-length(mu)
    tmp1<-eigen(vari)$values
    tmp2<-eigen(vari)$vectors   
    result<-matrix(0,n,p)   
    for (i in 1:p)
    {result[,i]<-rnorm(n,mean=0,sd=sqrt(tmp1[i]))}   
    for (i in 1:n)
    {result[i,]<-tmp2%*%result[i,]+mu}
    }  
    result
    }
    
    match.margin<-function(vec)   
    {range1<-vec[1:2]
    vec1<-vec[-(1:2)]
    range2<-range(vec1,na.rm=T)
    vec1<-range1[1]+diff(range1)/diff(range2)*(vec1-range2[1])
    vec1
    }
    
    gen.mult<-function(vec)
    {if(sum(is.na(vec))>0)
      return(rep(NA,length(vec)))
      else{ 
        l<-1-sum(vec)
        l<-ifelse(l<0,0,l)
        return(rmultinom(1,size=1,prob=c(l,vec))[-1])}
    }
    
    x1=data.frame(x1)
    temp.namec=colnames(x1)
    indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
    if(!is.null(cova))
      if(length(grep("for.m",names(cova)))!=0)
        for (i in 1:length(cova[[2]]))
          indi=c(indi,grep(cova[[2]][i],temp.namec))
    
    means<-NULL
    z<-dirx
    z.name=paste("predictor",1:ncol(z),sep=".")
    colnames(z)=z.name
    
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)   #create the predictor matrix z
      z<-cbind(z,cova)
    else 
      z1<-cbind(z,cova[[1]])}
    
    binm1<-binm
    
    if(!is.null(catm))
    {for (i in 2:(catm$n+1))
      binm1<-c(binm1,catm[[i]])}
    if(!is.null(binm1))
      for (i in 1:length(binm1))
      {if(binm1[i]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z1)))
      else  
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z)))}
    if(!is.null(contm))
      for (i in (length(binm1)+1):length(c(binm1,contm)))
      {if(contm[i-length(binm1)]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z1)))
      else
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z)))}
    
    if(dim(means)[2]==1)                                                   #added in the new program, in case there is only one mediator
    {sim.m<-suppressWarnings(rnorm(length(means),mean=means,sd=sqrt(distmgivenx$varmat)))     #added in the new program
    sim.m2<-match.margin(c(range(means,na.rm=T),sim.m))}                          #added in the new program   
    else{
      sim.m<-t(apply(means,1,mult.norm,vari=distmgivenx$varmat,n=1))
      
      range.means<-apply(means,2,range,na.rm=T)
      
      sim.m2<-apply(rbind(range.means,sim.m),2,match.margin)    #to make the simulate fit the means' ranges
    }
    sim.m2<-data.frame(sim.m2)
    n<-dim(sim.m2)[1]
    if(!is.null(binm))
      for (i in 1:length(binm))
        sim.m2[,i]<-rbinom(n,size=1,prob=sim.m2[,i])
    
    if(!is.null(catm))
    {j<-length(binm)+1
    for (i in 2:(catm$n+1))
    {a<-sim.m2[,j:(j+length(catm[[i]])-1)]
    sim.m2[,j:(j+length(catm[[i]])-1)]<-t(apply(a,1,gen.mult))
    j<-j+length(catm[[i]])}
    }
    
    x1[,c(binm1,contm)]<-sim.m2
    
    x1
    }
    
    if(is.null(catm))
      multi=jointm
    else if(is.null(jointm))
      multi=catm
    else {temp1<-catm
    temp2<-jointm
    temp1[[1]]=catm[[1]]+jointm[[1]]
    temp2[[1]]<-NULL
    multi=append(temp1,temp2)} 
    listm=list(single=c(contm,binm),multi=multi)
    
    if (is.null(multi))                      #allm list all mediators
    {tempm<-multi
    tempm[[1]]<-NULL}
    else  tempm<-NULL
    allm<-unique(c(contm,binm,unlist(tempm)))
    nonmissing<-apply(cbind(y,x[,listm$single],dirx),1,anymissing)
    temp.name1=colnames(x)
    x<-data.frame(x[nonmissing,])
    colnames(x)=temp.name1
    y<-data.frame(y[nonmissing,])
    if(!is.null(cova))
    {cova=data.frame(cova[nonmissing,])
    colnames(cova)=cova_names}
    colnames(y)<-ynames
    pred<-data.frame(dirx[nonmissing,])
    pred1<-data.frame(dirx[nonmissing, dirx1])
    colnames(pred)<-pred_names
    colnames(pred1)<-pred_names[dirx1]
    w<-w[nonmissing]
    nonmissing1<-apply(cbind(x.new[,listm$single],pred.new),1,anymissing)
    temp.name1=colnames(x.new)
    x.new<-data.frame(x.new[nonmissing1,])
    colnames(x.new)=temp.name1
    w.new<-w.new[nonmissing1]
    pred.new<-data.frame(pred.new[nonmissing1,])
    pred.new1<-data.frame(pred.new[nonmissing1,dirx1])
    colnames(pred.new)<-pred_names
    colnames(pred.new1)<-pred_names[dirx1]
    if(!is.null(cova.new))  
    {cova.new=data.frame(cova.new[nonmissing1,])
    colnames(cova.new)=cova_names}
    
    #1.fit the model
    x2<-cbind(x,pred)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    
    for(j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      
      if(!is.null(custom.function))
      { if(!is.na(custom.function[j]))
      {cf1=gsub("responseY","y[,j]",custom.function[j])
      cf1=gsub("dataset123","x2",cf1)
      cf1=gsub("weights123","w",cf1)
      full.model[[j]]<-eval(parse(text=cf1))}
        else if(nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                   distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
        }
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
        else
          full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
        }
      }
      else if(nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                 distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
      }
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
      else
        full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    n.new<-nrow(x.new)
    
    #3. get the joint distribution of m given x
    distmgivenx<-dist.m.given.x(x,pred,binm,contm,catm,nonlinear,df1,w,cova)
    te1.0<-NULL
    denm1.0<-NULL
    denm1.1<-NULL
    n1<-dim(x)[1]
    
    #4. repeat to get the mediation effect
    for (l in 1:length(dirx1)) {
      denm1<-NULL
      denm1.2=NULL
      te1<-NULL
      for (k in 1:n)
      {new0<-sim.xm(distmgivenx,x.new,pred.new,binm,contm,catm,nonlinear,df1,cova.new) #draw ms conditional on x.new
      temp.pred<-pred.new
      temp.pred[,l]<-temp.pred[,dirx1[l]]+margin
      if(!is.null(xmod))   #allows the interaction of pred with xmod
      {cova.new1=cova.new
      x.new1=x.new
      if(!is.null(cova.new))
      {temp.cova=intersect(grep(pred_names[dirx1[l]],cova_names),grep(xmod,cova_names))
      if(sum(temp.cova)>0)
      {m.t=1
      m.t2=form.interaction(cova.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.cova)
      {cova.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}
      }}
      temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(x.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.x)
      {x.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}}
      new1<-sim.xm(distmgivenx,x.new1,temp.pred,binm,contm,catm,nonlinear,df1,cova.new1)  #draw from the conditional distribution of m given x
      }
      else
        new1<-sim.xm(distmgivenx,x.new,temp.pred,binm,contm,catm,nonlinear,df1,cova.new)  #draw from the conditional distribution of m given x
      new1<-cbind(new1,temp.pred)   #draw ms conditional on x.new+margin
      new0<-cbind(new0,pred.new) 
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      denm2<-NULL
      
      #browser()   
      
      sample.temp<-sample(1:n.new,2*n.new,replace = T,prob=w.new)   #random sample from the original data
      
      #4.0.0 get the total indirect effect
      temp.new1<-new1
      temp.new1[,allm]<-x.new[sample.temp[1:n.new],allm]
      temp.new0<-new0
      temp.new0[,allm]<-x.new[sample.temp[(n.new+1):(2*n.new)],allm]
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(x.new[sample.temp[1:n.new],],x.new[sample.temp[1:n.new],z],inter.cov=xmod)
          m.t3=form.interaction(x.new[sample.temp[(n.new+1):(2*n.new)],],x.new[sample.temp[(n.new+1):(2*n.new)],z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {temp.new1[,m.t1]=m.t2[,m.t]
          temp.new0[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
        {if(is.null(type))
          type="link"
          denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin
          }
      else if(surv[m])
        denm3<-(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin
      else
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin
      
      #4.0 get the direct effect
      temp.new1<-x.new[sample.temp[1:n.new],]
      temp.new1=cbind(temp.new1,temp.pred)
      temp.new0<-x.new[sample.temp[(n.new+1):(2*n.new)],]
      temp.new0=cbind(temp.new0,pred.new)
      colnames(temp.new1)<-c(xnames,pred_names)
      colnames(temp.new0)<-c(xnames,pred_names)
      
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(temp.new1,temp.pred[,dirx1[l]],inter.cov=xmod)
        m.t3=form.interaction(temp.new0,pred.new[,dirx1[l]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {temp.new1[,m.t1]=m.t2[,m.t]
        temp.new0[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
      }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin)
      else
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin)
      
      #4.1 get the te
      te0<-NULL
      for(m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m],type=type)-predict(full.model[[m]],new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        te0<-c(te0, (predict(full.model[[m]],new1,type=type)-predict(full.model[[m]],new0,type=type))/margin)
      else
        te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m])-predict(full.model[[m]],new0,best.iter1[m]))/margin)
      te1<-cbind(te1,te0)
      
      #4.2 mediation effect from the single mediator
      # browser()
      if (!is.null(listm$single))
        for (i in 1:length(listm$single))
        {new1.nm<-new1
        new0.nm<-new0
        temp.m<-x.new[sample.temp,listm$single[i]]
        new1.nm[,listm$single[i]]<-temp.m[1:n.new]    #draw m from its original distribution
        new0.nm[,listm$single[i]]<-temp.m[(n.new+1):(2*n.new)]    #draw m from its original distribution
        
        if(!is.null(xmod))
        {temp.x=intersect(grep(xnames[listm$single[i]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new1.nm,new1.nm[,listm$single[i]],inter.cov=xmod)
        m.t3=form.interaction(new0.nm,new0.nm[,listm$single[i]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new1.nm[,m.t1]=m.t2[,m.t]
        new0.nm[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      
      #4.3.mediation effect from the joint mediator
      if (!is.null(listm$multi))
        for (i in 2:(listm$multi[[1]]+1))
        {new1.nm<-new1
        new0.nm<-new0
        new1.nm[,listm$multi[[i]]]<-x.new[sample.temp[1:n.new],listm$multi[[i]]]    #draw m from its original distribution
        new0.nm[,listm$multi[[i]]]<-x.new[sample.temp[(n.new+1):(2*n.new)],listm$multi[[i]]]    #draw m from its original distribution
        
        if(!is.null(xmod))
          for (z in listm$multi[[i]])
          {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new1.nm,new1.nm[,z],inter.cov=xmod)
          m.t3=form.interaction(new0.nm,new0.nm[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new1.nm[,m.t1]=m.t2[,m.t]
          new0.nm[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
          }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      denm1<-rbind(denm1,denm2)
      denm1.2=rbind(denm1.2,as.matrix(denm3))
      }
      denm1.0[[l]]<-denm1 
      denm1.1[[l]]<-denm1.2 
      te1.0[[l]]<-te1
    } 
    
    #4.4 get the indirect effects
    denm<-NULL
    denm1<-NULL
    te<-NULL
    ie<-NULL
    for (l in 1:length(dirx1))
    {denm[[l]]<-apply(denm1.0[[l]],2,col_mean,n.new)
    denm1[[l]]<-apply(denm1.1[[l]],2,col_mean,n.new)
    te0<-matrix(apply(te1.0[[l]],1,mean),n.new)
    #te<-cbind(te,te0)
    temp1<-ncol(denm[[l]])/ncol(te0)
    temp2<-NULL
    for(temp in 1:temp1)
      temp2<-cbind(temp2,te0)
    ie[[l]]<-temp2-denm[[l]]
    ie[[l]][,1:ncol(y)]=matrix(rep(te0,ncol(y)),ncol=ncol(y))-denm1[[l]]      #the total indirect effect
    te=cbind(te,ie[[l]][,1:ncol(y)]+denm[[l]][,1:ncol(y)])                    #the total effect
    if(!is.null(listm$multi)) 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    if(!is.null(listm$multi))
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    }
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
    names(denm)<-pred_names[dirx1]
    names(ie)<-pred_names[dirx1]
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear,Survival=surv, type=type, model=full.model,best.iter=best.iter1),pred.new=pred.new,w.new=w.new,data=data,distmgivenx=distmgivenx)
    class(a)<-"med"
    return(a)
  }
  
  anymissing<-function(vec)
  {if(sum(is.na(vec))>0)
    return(F)
    else return(T)
  }
  
if (is.null(c(binm,contm,catm)))
  stop("Error: no potential mediator is specified")
#  browser() 
  
xnames<-colnames(x)
pred_names<-colnames(dirx)
ynames=colnames(y)
if(!is.null(cova)){
  if(length(grep("for.m",names(cova)))==0)
   cova_names=colnames(cova)
  else 
   cova_names=colnames(cova[[1]])}
if(is.character(contm))
  contm<-unlist(sapply(contm,grep,xnames))
if(is.character(binm))
  binm<-unlist(sapply(binm,grep,xnames))
if(!is.null(catm))
  for (i in 2:length(catm))
    if(is.character(catm[[i]]))
      catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
if(!is.null(jointm))
  for (i in 2:length(jointm))
    if(is.character(jointm[[i]]))
      jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))

#set.seed(seed)

if(is.null(catm))
{multi=jointm
name1<-NULL                       #added in the new program
if (!is.null(multi))              #added in the new program, in case that multi is NULL
  name1<-paste("j",1:multi[[1]],sep="")}
else if(is.null(jointm))
{multi=catm
name1<-NULL
for (i in 2:(catm[[1]]+1))
  name1<-c(name1,colnames(x)[multi[[i]][1]])}
else {temp1<-catm
temp2<-jointm
temp1[[1]]=catm[[1]]+jointm[[1]]
temp2[[1]]<-NULL
multi=append(temp1,temp2)
name1<-NULL
for (i in 2:(catm[[1]]+1))
  name1<-c(name1,colnames(x)[multi[[i]][1]])
name1<-c(name1,paste("j",1:jointm[[1]],sep=""))} 
listm=list(single=c(contm,binm),multi=multi)

ny=ncol(y)
nx=length(dirx1)
te<-matrix(0,n2+1,ny*nx)
de<-matrix(0,n2+1,ny*nx)
mul<-ifelse(is.null(multi),0,multi[[1]])        #added in the new program, in case multi is null
ie<-matrix(0,n2,ny*(1+length(listm$single)+mul))   #added in the new program
ie1<-matrix(0,nx,ny*(1+length(listm$single)+mul))   #added in the new program
if(!is.null(listm$multi))
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
   colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
   rownames(ie1)<-pred_names[dirx1]}
else 
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
   colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
   rownames(ie1)<-pred_names[dirx1]}
ie<-rep(list(ie),nx)
names(ie)<-pred_names[dirx1]

temp.med<-med.contx(data=NULL,x=x,y=y,dirx=dirx, dirx1=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova, 
                margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,distn=distn,family1=family1,biny=biny,
                refy=refy,x.new=x.new,pred.new=pred.new, cova.new=cova.new, surv=surv,type=type,w=w,w.new=w.new,
                xmod=xmod,custom.function = custom.function)
temp=temp.med
temp.1<-NULL
for (l in 1:nx)
 temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
if(is.null(w.new))
{te[1,]<-apply(temp$te,2,mean,na.rm=T)
 de[1,]<-apply(temp.1,2,mean,na.rm=T) 
 for (l in 1:nx)
   ie1[l,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
}
else
{te[1,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
 de[1,]<-apply(temp$denm[,1],2,weighted.mean,na.rm=T,w=w.new) 
 for (l in 1:nx)
   ie1[l,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T,w=w.new)  #first row is the estimated value
}


te1<-NULL                      #to store the mediation effects on predictor
de1<-NULL
ie2<-rep(list(NULL),nx)
names(ie2)<-pred_names[dirx1]
model<-temp$model
all_model=NULL
all_iter=NULL
all_boot=NULL

for (i in 1:n2)
{boots<-sample(1:nrow(x),replace=T, prob=w)
 x1<-data.frame(x[boots,])
 colnames(x1)=xnames
 y1<-data.frame(y[boots,])
 colnames(y)=ynames
 dirx1.temp<-data.frame(dirx[boots,])
 colnames(dirx1.temp)=pred_names
 if(!is.null(cova)){
   if(length(grep("for.m",names(cova)))==0)
    {cova1<-data.frame(cova[boots,])
     colnames(cova1)=cova_names}
   else 
   {cova1=cova
    cova1[[1]]=data.frame(cova[[1]][boots,])
    colnames(cova1[[1]])=cova_names
    names(cova1[[1]])=names(cova[[1]])}}
 else
   cova1=NULL
 temp<-med.contx(data=NULL,x=x1,y=y1,dirx=dirx1.temp,dirx1=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova1, 
                 margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,
                 distn=distn,family1=family1,biny=biny,refy=refy,x.new=x.new,pred.new=pred.new,cova.new=cova.new,surv=surv,
                 type=type,xmod=xmod,custom.function = custom.function) #added to the new codel, change the seed to make different results
 if(all.model)
   {all_model[[i]]=temp$model$model
    all_iter=rbind(all_iter,temp$model$best.iter)
    all_boot=rbind(all_boot,boots)}
 temp.1<-NULL
 for (l in 1:nx)
   temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
 if(is.null(w.new))
   {te[1+i,]<-apply(temp$te,2,mean,na.rm=T)
    de[1+i,]<-apply(temp.1,2,mean,na.rm=T)
    for (l in 1:nx)
      ie[[l]][i,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
   }
else
{te[1+i,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
 de[1+i,]<-apply(temp$denm[,1],weighted.mean,na.rm=T,w=w.new)
 for (l in 1:nx)
   ie[[l]][i,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T)  #first row is the estimated value
}
te1<-cbind(te1,temp$te)
de1<-cbind(de1,temp.1)
for (l in 1:nx)
  ie2[[l]]<-rbind(ie2[[l]],temp$ie[[l]])
print(i)
}
colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
missing.pred.new<-apply(data.frame(pred.new),1,anymissing)
pred.new<-data.frame(pred.new[missing.pred.new,])

a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model,
        data=list(x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm, jointm=jointm, cova=cova, binpred=NULL,
                  contpred=dirx1,catpred=NULL),
        boot.detail=list(pred.new=pred.new,cova.new=cova.new,te1=te1,de1=de1,ie1=ie2),w.new=w.new,
        all_model=all_model,all_iter=all_iter,all_boot=all_boot,mod=F,med=temp.med)
class(a)<-"mma"
return(a)
}

if(is.null(data)){
  surv=rep(F,ncol(y))
  biny=rep(F,ncol(y))
  if(is.null(distn))
    distn<-rep(NA,ncol(y))
  for(j in 1:ncol(y)) {
    if(class(y[,j])=="Surv"){
      surv[j]=T
      if(is.na(distn[j]))
        distn[j]="coxph"
      if(is.null(type) & nonlinear)
        type="response"
      else if (is.null(type))
        type="risk"
    }
    else if(is.character(y[,j]) | is.factor(y[,j]) | nlevels(as.factor(y[,j]))==2)
    {biny[j]=T
    if(is.na(family1[[j]]))
      family1[[j]] = binomial("logit")
    if(is.na(distn[j]))
      distn[j]="bernoulli" 
    if(!is.na(refy[j]))
      y[,j]<-ifelse(y[,j]==refy[j],0,1)
    else
      y[,j]<-ifelse(as.factor(y[,j])==levels(as.factor(y[,j]))[1],0,1)
    }
    else { 
      if(is.na(family1[[j]]))
        family1[[j]] = gaussian(link = "identity")
      if(is.na(distn[j]))
        distn[j]="gaussian" 
    }
  }
}
else
{ if(is.null(data$bin.results))
{y=data$cont.results$y
 y_type=data$cont.results$y_type
 binpred=NULL
 catpred=NULL
 contpred=data$cont.results$contpred}
  else 
  {y=data$bin.results$y
   y_type=data$bin.results$y_type
   binpred=data$bin.results$binpred
   catpred=data$bin.results$catpred
   contpred=data$bin.results$contpred}
  biny=(y_type==2)
  surv=(y_type==4)
  if(sum(surv)>0 & is.null(type) & nonlinear)
    type="response"
  else if (sum(surv)>0 & is.null(type))
    type="risk"
  if(is.null(distn))
    distn<-rep(NA,ncol(y))
  distn[is.na(distn) & y_type==2]="bernoulli"
  distn[is.na(distn) & y_type==4]="coxph"
  distn[is.na(distn) & y_type==1]="gaussian"
  }

a.binx=NULL
a.contx=NULL

if(!(is.null(binpred) & is.null(catpred))){
  if(!is.null(data$bin.results)) {
    data2=data$bin.results
    x=data2$x
    y=data2$y
    dirx=data2$dirx
    binm=data2$binm
    contm = data2$contm
    catm = data2$catm
    jointm = data2$jointm
    cova=data2$cova
    allm = c(contm, catm)
    family1=data2$family1
    binpred=data2$binpred
    catpred=data2$catpred}
  if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
  
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  ynames<-colnames(y)
  if(!is.null(cova)) {
    if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else 
      cova_names=colnames(cova[[1]])}
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(binm))
    binm<-unlist(sapply(binm,grep,xnames))
  
  a.binx<-boot.med.binx(data=data$bin.results,x=x, y=y,dirx=dirx,contm=contm,catm=catm,
                        jointm=jointm,cova=cova,n=n,n2=n2,nonlinear=nonlinear,nu=nu, binpred=binpred,catpred=catpred,
                        D=D,distn=distn,family1=family1,
                        w=w,biny=biny,refy=rep(0,ncol(y)),surv,type,all.model,xmod,custom.function = custom.function)}

if(!is.null(contpred)){
  if(!is.null(data$cont.results)){
    data2=data$cont.results
    x=data2$x
    y=data2$y
    dirx=data2$dirx
    binm=data2$binm
    contm = data2$contm
    catm = data2$catm
    jointm = data2$jointm
    cova=data2$cova
    allm = c(contm, catm)
    family1=data2$family1
    binpred=data2$binpred
    if(is.null(x.new))
      x.new=x
    if(is.null(pred.new))
      pred.new=dirx 
    if(is.null(cova.new))
      cova.new=cova}
  
  a.contx<-boot.med.contx(data=data$cont.results,x=x,y=y,dirx=dirx,dirx1=contpred,binm=binm,contm=contm,
                    catm=catm, jointm=jointm, cova=cova,margin = margin, n = n,  
                    nonlinear = nonlinear, df1 = df1, nu = nu, D = D, distn = distn, 
                    family1 = family1, n2 = n2,w=w,biny=biny,refy=rep(0,ncol(y)),
                    x.new=x.new,pred.new=pred.new,cova.new=cova.new, surv,type,w.new,all.model,xmod,custom.function = custom.function)
}

a<-list(a.binx=a.binx, a.contx=a.contx)
class(a)<-"mma"
return(a)
}

    
  

mma<-function(x,y,pred,mediator=NULL, contmed=NULL,binmed=NULL,binref=NULL,
              catmed=NULL,catref=NULL,jointm=NULL,cova=NULL,refy=rep(NA,ncol(data.frame(y))),
              predref=rep(NA,ncol(data.frame(pred))),alpha=0.1,alpha2=0.1, margin=1, n=20,
              nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=as.list(rep(NA,ncol(data.frame(y)))),
              n2=50,w=rep(1,nrow(x)), testtype=1, x.new=NULL, pred.new=NULL,cova.new=NULL,type=NULL,
              w.new=NULL,all.model=FALSE,xmod=NULL,custom.function = NULL)
{boot.med.binx<-function(data,x=data$x, y=data$y,dirx=data$dirx,contm=data$contm,catm=data$catm,
                         jointm=data$jointm, cova=data$cova,n=20,n2=50,nonlinear=F,nu=0.001,binpred=data$binpred,catpred=data$catpred,
                         D=3,distn="bernoulli",family1=binomial("logit"),w=rep(1,nrow(x)),biny=(data$y_type==2),
                         refy=rep(NA,ncol(y)),surv=(data$y_type==4),type,all.model=FALSE,xmod=NULL,custom.function=NULL)
  #n2 is the time of bootstrap
{ med.binx<-function(data, x=data$x, y=data$y, dirx=data$dirx, dirx1=dirx, contm = data$contm, 
                     catm = data$catm, jointm = data$jointm, cova=data$cova, allm = c(contm, catm), 
                     n=20,nonlinear=F,nu=0.001,
                     D=3,distn=NULL,family1=data$family1, #
                     biny=rep(F,ncol(y)),refy=rep(0,ncol(y)),surv=rep(F,ncol(y)),type=NULL,
                     w=NULL,xmod=NULL,custom.function=NULL, full.model, best.iter1) #
  {if (is.null(allm))
    stop("Error: no potential mediator is specified")
    xnames<-colnames(x)
    pred_names<-colnames(dirx)  #
    pred_names1<-pred_names[dirx1]
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else
      cova_names=colnames(cova[[1]])}
    
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(catm))
      catm<-unlist(sapply(catm,grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    allm=c(contm,catm)
    
    te.binx<-function(full.model,new1,new0,best.iter1=NULL,surv,type)       
    {te<-NULL
    #browser()
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
    else if (surv[m])
      te[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    te
    }
    
    med.binx.contm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    marg.m<-c(nom1[,med],nom0[,med])[sample(1:n3,replace=T)]
    new1<-nom1
    new1[,med]<-marg.m[1:nrow(nom1)]
    new0<-nom0
    new0[,med]<-marg.m[(nrow(nom1)+1):n3]
    if(!is.null(xmod))
    {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
    if(sum(temp.x)>0)
    {m.t=1
    m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
    m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
    for (m.t1 in temp.x)
    {new0[,m.t1]=m.t2[,m.t]
    new1[,m.t1]=m.t3[,m.t]
    m.t=m.t+1}}
    }
    dir.nom<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
    else if(surv[m])
      dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    dir.nom
    }
    
    med.binx.jointm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,temp.rand,xmod,xnames)  
    {if (length(med)==1)                       #added for the new program, when there is only one mediator
    {if(is.factor(nom1[,med]))              #added to control for one factor mediator
      marg.m<-as.factor(c(as.character(nom1[,med]),as.character(nom0[,med]))[temp.rand])
    else
      marg.m<-c(nom1[,med],nom0[,med])[temp.rand]
    }        
      else                                         #added for the new program
        marg.m<-rbind(nom1[,med],nom0[,med])[temp.rand,]
      new1<-nom1
      new0<-nom0
      if(length(med)==1)                                       #added for the new program, when there is only one mediator
      {new1[,med]<-marg.m[1:nrow(new1)]                     #added for the new program 
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0))]}  #added for the new program
      else                                                     #added for the new program
      {new1[,med]<-marg.m[1:nrow(new1),]
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0)),]}
      if(!is.null(xmod))
        for (z in med)
        {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
        m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0[,m.t1]=m.t2[,m.t]
        new1[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
      dir.nom<-NULL
      for (m in 1:length(full.model))
        if(surv[m] & !is.null(best.iter1[m])){
          if(is.null(type))
            type="link"
          dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)}
      else if(surv[m])
        dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      dir.nom
    }
    
    med.binx.catm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    temp.rand<-unlist(list(nom1[,med],nom0[,med]))[sample(1:n3,replace=T)]
    marg.m1<-temp.rand[1:nrow(nom1)]
    marg.m2<-temp.rand[(nrow(nom1)+1):n3]
    dir.nom<-rep(0,length(full.model))
    for (m in 1:length(full.model))
      for (i in levels(x[,med]))
      {new1<-nom1
      new1[1:dim(new1)[1],med]<-i
      new0<-nom0
      new0[1:dim(new0)[1],med]<-i
      if(!is.null(xmod))
      {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
      m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
      for (m.t1 in temp.x)
      {new0[,m.t1]=m.t2[,m.t]
      new1[,m.t1]=m.t3[,m.t]
      m.t=m.t+1}}
      }
      p<-mean(temp.rand==i,na.rm=T)
      if(surv[m] & !is.null(best.iter1[m])){
        if(is.null(type))
          type="link"
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T))}
      else if(surv[m])
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T))
      else
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T))
      }
    dir.nom
    }
    
    #1.fit the model
    
    #2. prepare for the store of results
    #set.seed(seed)
    te<-matrix(0,n,ncol(y)*length(dirx1))
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
    if(!is.null(jointm))
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))+jointm[[1]]))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")
    }
    else
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".")
    }
    denm<-rep(list(denm),length(dirx1))
    ie<-denm
    #3. repeat to get the mediation effect
    for (k in 1:n)
    {#3.1 get the te         full.model,x,y,dirx,best.iter1=NULL
      x0.temp<-apply(as.matrix(dirx[,dirx1]==1),1,sum)==0  #indicator of the reference group
      x0<-x2[x0.temp,]
      if(is.null(w))
      {w1<-NULL
      w0<-NULL}
      else
        w0<-w[x0.temp]
      for (l in 1:length(dirx1))  #l indicate the lth predictor
      {x1.2<-x2[dirx[,dirx1[l]]==1,]
      if(!is.null(w))
        w1<-w[dirx[,dirx1[l]]==1]
      #n3<-dim(x)[1] use the original size
      new1<-x1.2[sample(1:nrow(x1.2),replace=T,prob=w1),] #floor(n3/2),
      new0<-x0[sample(1:nrow(x0),replace=T,prob=w0),] #floor(n3/2),
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-te.binx(full.model,new1,new0,best.iter1,surv,type)  
      temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
      #the indirect effect of all mediators
      temp.ie<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-med.binx.jointm(full.model,new1,new0,allm,best.iter1,surv,type,temp.rand,xmod,xnames) #add temp.rand
      #new method to calculate the direct effect     
      x.temp=data.frame(x[dirx[,dirx1[l]]==1 | x0.temp,])
      new1.temp=data.frame(x.temp[temp.rand[1:nrow(x1.2)],],dirx[dirx[,dirx1[l]]==1,])
      new0.temp=data.frame(x.temp[temp.rand[(nrow(x1.2)+1):(nrow(x1.2)+nrow(x0))],],dirx[x0.temp,])
      colnames(new1.temp)<-c(xnames,pred_names)
      colnames(new0.temp)<-c(xnames,pred_names)
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names1[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0.temp,dirx[x0.temp,],inter.cov=xmod)
        m.t3=form.interaction(new1.temp,dirx[dirx[,dirx1[l]]==1,],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0.temp[,m.t1]=m.t2[,m.t]
        new1.temp[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}}
      denm[[l]][k,1:ncol(y)]<-te.binx(full.model,new1.temp,new0.temp,best.iter1,surv,type) #add temp.rand
      
      j<-2
      #3.2 mediation effect from the continuous mediator
      if (!is.null(contm))
        for (i in contm)          #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.contm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.3.mediation effect from the categorical mediator
      if (!is.null(catm))
        for (i in catm)           #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.catm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.4 mediation effect from the joint mediators
      if (!is.null(jointm))
        for (i in 1:jointm[[1]])          #full.model,x,y,med,dirx,best.iter1=NULL
        {temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
        denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.jointm(full.model,new1,new0,jointm[[i+1]],best.iter1,surv,type,temp.rand,xmod,xnames)
        j<-j+1}
      #3.5 get the indirect effects and total effect
      ie[[l]][k,]<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-denm[[l]][k,]
      ie[[l]][k,1:ncol(y)]<-temp.ie
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-denm[[l]][k,1:ncol(y)]+temp.ie
      
      if(!is.null(jointm))
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")#c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep=""))
      else
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".") #c("all",colnames(x)[c(contm,catm)])
      }
    }
    names(denm)<-pred_names1
    names(ie)<-pred_names1
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear, Survival=surv, type=type, model=full.model,best.iter=best.iter1),data=data)
    #class(a)<-"med"
    return(a)
  }
  
  if (is.null(c(contm,catm)))
    stop("Error: no potential mediator is specified")
  
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  pred_names1<-pred_names[c(binpred,unlist(catpred))]
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else 
      cova_names=colnames(cova[[1]])}
  ynames=colnames(y)
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(catm))
    catm<-unlist(sapply(catm,grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))

  #set.seed(seed)
  allm=c(contm,catm)
  ny=ncol(y)
  nx=length(binpred)+length(unlist(catpred))
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  if(is.null(jointm))
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))))
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  rownames(ie1)<-pred_names1}
  else 
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie1)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  rownames(ie1)<-pred_names1}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names1
  
  #1.fit the model
  x2<-cbind(x,dirx)
  colnames(x2)<-c(xnames,pred_names)
  full.model<-NULL
  best.iter1<-NULL

  for (j in 1:ncol(y)){
    if(biny[j])                     #recode y if y is binary
      y[,j]<-ifelse(y[,j]==refy[j],0,1)
    x1<-x2[!is.na(y[,j]),]             #delete nas in y for mart
    y1<-y[!is.na(y[,j]),j]
    w1<-w[!is.na(y[,j])]
    if(!is.null(custom.function)){
      if(!is.na(custom.function[j])){
        cf1=gsub("responseY","y1",custom.function[j])
        cf1=gsub("dataset123","x1",cf1)
        cf1=gsub("weights123","w1",cf1)
        full.model[[j]]<-eval(parse(text=cf1))
      }
      else if (nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                 distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
      else
        full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
      }
    }
    else if (nonlinear)
    {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                               distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
    best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
    while(full.model[[j]]$n.trees-best.iter1[j]<30){
      full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
    else
    {if(surv[j])
      full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
    else
      full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
    }
  }
  
  a.binx<-NULL
  if(!is.null(binpred))
    for(i in binpred)
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=i, contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  
  if(!is.null(catpred))
    for(i in 1:length(catpred))
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=catpred[[i]], contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x, y=y, dirx=dirx, dirx1=catpred[[i]], contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  
  #temp<-med.binx(data=NULL,x,y,dirx,contm,catm,jointm,cova,allm,n,nonlinear,nu,D,distn,family1,
  #               biny,refy,surv,type,w=w,xmod,custom.function=custom.function)
  temp=a.binx
  te[1,]<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie1[l,]<-apply(temp$ie[[l]],2,mean)}  #first row is the estimated value
  de[1,]<-apply(temp.1,2,mean,na.rm=T)
  model<-temp$model
  all_model=NULL #to store all fitted models if all.model is TRUE
  all_iter=NULL
  all_boot=NULL
  
  for (t.i in 1:n2)
  {boots<-sample(1:nrow(x),replace=T,prob=w)
  x.temp<-data.frame(x[boots,])
  names(x.temp)=xnames
  y.temp<-data.frame(y[boots,])
  colnames(y.temp)=ynames
  pred.temp<-data.frame(dirx[boots,])
  colnames(pred.temp)=pred_names
  w1=NULL
  
  #1.fit the model
  x2<-cbind(x.temp,pred.temp)
  colnames(x2)<-c(xnames,pred_names)
  full.model<-NULL
  best.iter1<-NULL
  
  for (j in 1:ncol(y.temp)){
    if(biny[j])                     #recode y if y is binary
      y.temp[,j]<-ifelse(y.temp[,j]==refy[j],0,1)
    x1<-x2[!is.na(y.temp[,j]),]             #delete nas in y for mart
    y1<-y.temp[!is.na(y.temp[,j]),j]
    w1<-w[!is.na(y.temp[,j])]
    if(!is.null(custom.function)){
      if(!is.na(custom.function[j])){
        cf1=gsub("responseY","y1",custom.function[j])
        cf1=gsub("dataset123","x1",cf1)
        cf1=gsub("weights123","w1",cf1)
        full.model[[j]]<-eval(parse(text=cf1))
      }
      else if (nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                 distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
      else
        full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
      }
    }
    else if (nonlinear)
    {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                               distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
    best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
    while(full.model[[j]]$n.trees-best.iter1[j]<30){
      full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
    else
    {if(surv[j])
      full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
    else
      full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
    }
  }
  
  a.binx<-NULL
  if(!is.null(binpred))
    for(i in binpred)
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=i, contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=i, contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  
  if(!is.null(catpred))
    for(i in 1:length(catpred))
    {if(is.null(a.binx))
      a.binx<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=catpred[[i]], contm = contm, 
                       catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                       nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                       custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    else
    {a<-med.binx(data=NULL, x=x.temp, y=y.temp, dirx=pred.temp, dirx1=catpred[[i]], contm = contm, 
                 catm=catm, jointm=jointm,cova=cova, allm=allm, n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                 biny=biny,refy=refy,surv=surv,type=type,w=w,xmod=xmod,
                 custom.function=custom.function,full.model=full.model,best.iter1=best.iter1)
    a.binx$te=cbind(a.binx$te,a$te)
    a.binx$denm=list(a.binx$denm,a$denm)
    a.binx$ie=list(a.binx$ie,a$ie)}
    }
  temp=a.binx
  #temp<-med.binx(data=NULL,x=x1, y=y1, dirx=pred1, contm=contm, catm=catm,jointm=jointm,cova=cova,allm=allm,n=n,
  #                nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,biny=biny,refy=refy,surv=surv,type=type,w=NULL,
  #               xmod=xmod,custom.function = custom.function)
  if(all.model)
  {all_model[[t.i]]=temp$model$model
  all_iter=rbind(all_iter,temp$model$best.iter)
  all_boot=rbind(all_boot,boots)}
  te[1+t.i,]<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie[[l]][t.i,]<-apply(temp$ie[[l]],2,mean,na.rm=T)}  #first row is the estimated value
  de[1+t.i,]<-apply(temp.1,2,mean,na.rm=T)
  print(t.i)
  }
  
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names1,each=ncol(y)),sep=".")
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model, 
          data=list(x=x,y=y,dirx=dirx,contm=contm,catm=catm,jointm=jointm,binpred=binpred,contpred=NULL,catpred=catpred),
          all_model=all_model,all_iter=all_iter,all_boot=all_boot,mod=F)
  class(a)<-"mma"
  return(a)
}

boot.med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,dirx1=data$contpred,binm=data$binm,contm=data$contm,
                         catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                         nonlinear=F,df1=1,nu=0.001,D=3,distn="gaussian",
                         family1=gaussian(link="identity"),n2=50,w=rep(1,nrow(x)),
                         biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx,
                         cova.new=cova,surv,type,w.new=NULL,all.model=all.model,xmod=NULL,
                         custom.function = custom.function)
{
  med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx, dirx1=data$contpred, binm=data$binm,contm=data$contm,
                      catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                      nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=data$family1,
                      biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx, cova.new=cova, surv=(data$y_type==4),
                      type=NULL,w=NULL, w.new=NULL, xmod=NULL,custom.function=NULL)
  {if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
    # browser()
    xnames<-colnames(x)
    pred_names<-colnames(dirx)
    ynames<-colnames(y)
    if(!is.null(cova)) {
      if(length(grep("for.m",names(cova)))==0)
        cova_names=colnames(cova)
      else 
        cova_names=colnames(cova[[1]])}
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(binm))
      binm<-unlist(sapply(binm,grep,xnames))
    if(!is.null(catm))
      for (i in 2:length(catm))
        if(is.character(catm[[i]]))
          catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    anymissing<-function(vec) #return T if there is any missing in the vec
    {if(sum(is.na(vec))>0)
      return(F)
      else return(T)
    }
    
    col_mean<-function(col,n.row,w=NULL)
    {temp<-matrix(col,n.row)
    if(is.null(w))
      return(apply(temp,1,mean,na.rm=T))
    else
      return(apply(temp,1,weighted.mean,na.rm=T,w=w))}
    
    
    dist.m.given.x<-function(x,dirx,binm=NULL,contm=NULL,catm=NULL,nonlinear,df1,w,cova) #give the model and residual of m given x
    {
      getform=function(z,nonlinear,df1)
      {if(!nonlinear)
        formu="x[,i]~."
      else
      {names.z=colnames(z)
      temp.t=unlist(lapply(z,is.character)) | unlist(lapply(z,is.factor))
      names.z1=names.z[!temp.t]
      names.z2=names.z[temp.t]
      if(length(names.z1)==0)
        formu="x[,i]~."
      else if (length(names.z2)==0)
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),sep="")
      else
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),"+",
                    paste(names.z2,collapse="+"),sep="")
      }
      formu
      }
      #browser()  
      models<-NULL
      x=data.frame(x)
      res<-NULL
      temp.namec=colnames(x)
      indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
      if(!is.null(cova))
        if(length(grep("for.m",names(cova)))!=0)
          for (i in 1:length(cova[[2]]))
            indi=c(indi,grep(cova[[2]][i],temp.namec))
      if(!is.null(catm))
      {for (i in 2:(catm$n+1))
        binm<-c(binm,catm[[i]])}
      
      z<-dirx
      z.name=paste("predictor",1:ncol(z),sep=".")
      colnames(z)=z.name
      # browser()
      if(!is.null(cova))
      {if (length(grep("for.m",names(cova)))==0)#create the predictor matrix z
        z<-cbind(z,cova)
      else 
      {
        z1<-cbind(z,cova[[1]])
        form1=getform(z1,nonlinear,df1)
      }}
      
      form0=getform(z,nonlinear,df1)
      j<-1
      
      if(!is.null(binm))
      {for(i in binm)
      {if(!i%in%indi)
      {models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=binomial(link = "logit"),weights=w)
      res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z)))}
        else
        {models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=binomial(link = "logit"),weights=w)
        res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z1)))}
        j<-j+1}
      }
      # browser()
      for (i in contm)
      {if(!i%in%indi)
        models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=gaussian(link="identity"),weights=w)
      else
        models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=gaussian(link="identity"),weights=w)
      res<-cbind(res,models[[j]]$res)
      j<-j+1
      }
      list(models=models,varmat=var(res))
    }
    
    
    sim.xm<-function(distmgivenx,x1,dirx,binm,contm,catm,nonlinear,df1,cova)  #added nonlinear and df1 to sim.xm
    {mult.norm<-function(mu,vari,n) 
    {if (nrow(vari)!=ncol(vari)) 
      result<-c("Error: Variance matrix is not square")  
    else if (length(mu)!=nrow(vari)) 
      result<-c("Error: length mu is not right!")  
    else {   p<-length(mu)
    tmp1<-eigen(vari)$values
    tmp2<-eigen(vari)$vectors   
    result<-matrix(0,n,p)   
    for (i in 1:p)
    {result[,i]<-rnorm(n,mean=0,sd=sqrt(tmp1[i]))}   
    for (i in 1:n)
    {result[i,]<-tmp2%*%result[i,]+mu}
    }  
    result
    }
    
    match.margin<-function(vec)   
    {range1<-vec[1:2]
    vec1<-vec[-(1:2)]
    range2<-range(vec1,na.rm=T)
    vec1<-range1[1]+diff(range1)/diff(range2)*(vec1-range2[1])
    vec1
    }
    
    gen.mult<-function(vec)
    {if(sum(is.na(vec))>0)
      return(rep(NA,length(vec)))
      else{ 
        l<-1-sum(vec)
        l<-ifelse(l<0,0,l)
        return(rmultinom(1,size=1,prob=c(l,vec))[-1])}
    }
    
    x1=data.frame(x1)
    temp.namec=colnames(x1)
    indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
    if(!is.null(cova))
      if(length(grep("for.m",names(cova)))!=0)
        for (i in 1:length(cova[[2]]))
          indi=c(indi,grep(cova[[2]][i],temp.namec))
    
    means<-NULL
    z<-dirx
    z.name=paste("predictor",1:ncol(z),sep=".")
    colnames(z)=z.name
    
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)   #create the predictor matrix z
      z<-cbind(z,cova)
    else 
      z1<-cbind(z,cova[[1]])}
    
    binm1<-binm
    
    if(!is.null(catm))
    {for (i in 2:(catm$n+1))
      binm1<-c(binm1,catm[[i]])}
    if(!is.null(binm1))
      for (i in 1:length(binm1))
      {if(binm1[i]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z1)))
      else  
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z)))}
    if(!is.null(contm))
      for (i in (length(binm1)+1):length(c(binm1,contm)))
      {if(contm[i-length(binm1)]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z1)))
      else
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z)))}
    
    if(dim(means)[2]==1)                                                   #added in the new program, in case there is only one mediator
    {sim.m<-suppressWarnings(rnorm(length(means),mean=means,sd=sqrt(distmgivenx$varmat)))     #added in the new program
    sim.m2<-match.margin(c(range(means,na.rm=T),sim.m))}                          #added in the new program   
    else{
      sim.m<-t(apply(means,1,mult.norm,vari=distmgivenx$varmat,n=1))
      
      range.means<-apply(means,2,range,na.rm=T)
      
      sim.m2<-apply(rbind(range.means,sim.m),2,match.margin)    #to make the simulate fit the means' ranges
    }
    sim.m2<-data.frame(sim.m2)
    n<-dim(sim.m2)[1]
    if(!is.null(binm))
      for (i in 1:length(binm))
        sim.m2[,i]<-rbinom(n,size=1,prob=sim.m2[,i])
    
    if(!is.null(catm))
    {j<-length(binm)+1
    for (i in 2:(catm$n+1))
    {a<-sim.m2[,j:(j+length(catm[[i]])-1)]
    sim.m2[,j:(j+length(catm[[i]])-1)]<-t(apply(a,1,gen.mult))
    j<-j+length(catm[[i]])}
    }
    
    x1[,c(binm1,contm)]<-sim.m2
    
    x1
    }
    
    if(is.null(catm))
      multi=jointm
    else if(is.null(jointm))
      multi=catm
    else {temp1<-catm
    temp2<-jointm
    temp1[[1]]=catm[[1]]+jointm[[1]]
    temp2[[1]]<-NULL
    multi=append(temp1,temp2)} 
    listm=list(single=c(contm,binm),multi=multi)
    
    if (is.null(multi))                      #allm list all mediators
    {tempm<-multi
    tempm[[1]]<-NULL}
    else  tempm<-NULL
    allm<-unique(c(contm,binm,unlist(tempm)))
    nonmissing<-apply(cbind(y,x[,listm$single],dirx),1,anymissing)
    temp.name1=colnames(x)
    x<-data.frame(x[nonmissing,])
    colnames(x)=temp.name1
    y<-data.frame(y[nonmissing,])
    if(!is.null(cova))
    {cova=data.frame(cova[nonmissing,])
    colnames(cova)=cova_names}
    colnames(y)<-ynames
    pred<-data.frame(dirx[nonmissing,])
    pred1<-data.frame(dirx[nonmissing, dirx1])
    colnames(pred)<-pred_names
    colnames(pred1)<-pred_names[dirx1]
    w<-w[nonmissing]
    nonmissing1<-apply(cbind(x.new[,listm$single],pred.new),1,anymissing)
    temp.name1=colnames(x.new)
    x.new<-data.frame(x.new[nonmissing1,])
    colnames(x.new)=temp.name1
    w.new<-w.new[nonmissing1]
    pred.new<-data.frame(pred.new[nonmissing1,])
    pred.new1<-data.frame(pred.new[nonmissing1,dirx1])
    colnames(pred.new)<-pred_names
    colnames(pred.new1)<-pred_names[dirx1]
    if(!is.null(cova.new))  
    {cova.new=data.frame(cova.new[nonmissing,])
    colnames(cova.new)=cova_names}
    
    #1.fit the model
    x2<-cbind(x,pred)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    
    for(j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      
      if(!is.null(custom.function))
      { if(!is.na(custom.function[j]))
      {cf1=gsub("responseY","y[,j]",custom.function[j])
      cf1=gsub("dataset123","x2",cf1)
      cf1=gsub("weights123","w",cf1)
      full.model[[j]]<-eval(parse(text=cf1))}
        else if(nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                   distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
        }
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
        else
          full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
        }
      }
      else if(nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                 distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
      }
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
      else
        full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    n.new<-nrow(x.new)
    
    #3. get the joint distribution of m given x
    distmgivenx<-dist.m.given.x(x,pred,binm,contm,catm,nonlinear,df1,w,cova)
    te1.0<-NULL
    denm1.0<-NULL
    denm1.1<-NULL
    n1<-dim(x)[1]
    
    #4. repeat to get the mediation effect
    for (l in 1:length(dirx1)) {
      denm1<-NULL
      denm1.2=NULL
      te1<-NULL
      for (k in 1:n)
      {new0<-sim.xm(distmgivenx,x.new,pred.new,binm,contm,catm,nonlinear,df1,cova.new) #draw ms conditional on x.new
      temp.pred<-pred.new
      temp.pred[,l]<-temp.pred[,dirx1[l]]+margin
      if(!is.null(xmod))   #allows the interaction of pred with xmod
      {cova.new1=cova.new
      x.new1=x.new
      if(!is.null(cova.new))
      {temp.cova=intersect(grep(pred_names[dirx1[l]],cova_names),grep(xmod,cova_names))
      if(sum(temp.cova)>0)
      {m.t=1
      m.t2=form.interaction(cova.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.cova)
      {cova.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}
      }}
      temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(x.new,temp.pred[,dirx1[l]],inter.cov=xmod)
      for (m.t1 in temp.x)
      {x.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}}
      new1<-sim.xm(distmgivenx,x.new1,temp.pred,binm,contm,catm,nonlinear,df1,cova.new1)  #draw from the conditional distribution of m given x
      }
      else
        new1<-sim.xm(distmgivenx,x.new,temp.pred,binm,contm,catm,nonlinear,df1,cova.new)  #draw from the conditional distribution of m given x
      new1<-cbind(new1,temp.pred)   #draw ms conditional on x.new+margin
      new0<-cbind(new0,pred.new) 
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      denm2<-NULL
      
      #browser()   
      
      sample.temp<-sample(1:n.new,2*n.new,replace = T,prob=w.new)   #random sample from the original data
      
      #4.0.0 get the total indirect effect
      temp.new1<-new1
      temp.new1[,allm]<-x.new[sample.temp[1:n.new],allm]
      temp.new0<-new0
      temp.new0[,allm]<-x.new[sample.temp[(n.new+1):(2*n.new)],allm]
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(x.new[sample.temp[1:n.new],],x.new[sample.temp[1:n.new],z],inter.cov=xmod)
          m.t3=form.interaction(x.new[sample.temp[(n.new+1):(2*n.new)],],x.new[sample.temp[(n.new+1):(2*n.new)],z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {temp.new1[,m.t1]=m.t2[,m.t]
          temp.new0[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
        {if(is.null(type))
          type="link"
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin
        }
      else if(surv[m])
        denm3<-(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin
      else
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin
      
      #4.0 get the direct effect
      temp.new1<-x.new[sample.temp[1:n.new],]
      temp.new1=cbind(temp.new1,temp.pred)
      temp.new0<-x.new[sample.temp[(n.new+1):(2*n.new)],]
      temp.new0=cbind(temp.new0,pred.new)
      colnames(temp.new1)<-c(xnames,pred_names)
      colnames(temp.new0)<-c(xnames,pred_names)
      
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[dirx1[l]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(temp.new1,temp.pred[,dirx1[l]],inter.cov=xmod)
        m.t3=form.interaction(temp.new0,pred.new[,dirx1[l]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {temp.new1[,m.t1]=m.t2[,m.t]
        temp.new0[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
      }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin)
      else
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin)
      
      #4.1 get the te
      te0<-NULL
      for(m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m],type=type)-predict(full.model[[m]],new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        te0<-c(te0, (predict(full.model[[m]],new1,type=type)-predict(full.model[[m]],new0,type=type))/margin)
      else
        te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m])-predict(full.model[[m]],new0,best.iter1[m]))/margin)
      te1<-cbind(te1,te0)
      
      #4.2 mediation effect from the single mediator
      # browser()
      if (!is.null(listm$single))
        for (i in 1:length(listm$single))
        {new1.nm<-new1
        new0.nm<-new0
        temp.m<-x.new[sample.temp,listm$single[i]]
        new1.nm[,listm$single[i]]<-temp.m[1:n.new]    #draw m from its original distribution
        new0.nm[,listm$single[i]]<-temp.m[(n.new+1):(2*n.new)]    #draw m from its original distribution
        
        if(!is.null(xmod))
        {temp.x=intersect(grep(xnames[listm$single[i]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new1.nm,new1.nm[,listm$single[i]],inter.cov=xmod)
        m.t3=form.interaction(new0.nm,new0.nm[,listm$single[i]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new1.nm[,m.t1]=m.t2[,m.t]
        new0.nm[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      
      #4.3.mediation effect from the joint mediator
      if (!is.null(listm$multi))
        for (i in 2:(listm$multi[[1]]+1))
        {new1.nm<-new1
        new0.nm<-new0
        new1.nm[,listm$multi[[i]]]<-x.new[sample.temp[1:n.new],listm$multi[[i]]]    #draw m from its original distribution
        new0.nm[,listm$multi[[i]]]<-x.new[sample.temp[(n.new+1):(2*n.new)],listm$multi[[i]]]    #draw m from its original distribution
        
        if(!is.null(xmod))
          for (z in listm$multi[[i]])
          {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new1.nm,new1.nm[,z],inter.cov=xmod)
          m.t3=form.interaction(new0.nm,new0.nm[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new1.nm[,m.t1]=m.t2[,m.t]
          new0.nm[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
          }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      denm1<-rbind(denm1,denm2)
      denm1.2=rbind(denm1.2,as.matrix(denm3))
      }
      denm1.0[[l]]<-denm1 
      denm1.1[[l]]<-denm1.2 
      te1.0[[l]]<-te1
    } 
    
    #4.4 get the indirect effects
    denm<-NULL
    denm1<-NULL
    te<-NULL
    ie<-NULL
    for (l in 1:length(dirx1))
    {denm[[l]]<-apply(denm1.0[[l]],2,col_mean,n.new)
    denm1[[l]]<-apply(denm1.1[[l]],2,col_mean,n.new)
    te0<-matrix(apply(te1.0[[l]],1,mean),n.new)
    #te<-cbind(te,te0)
    temp1<-ncol(denm[[l]])/ncol(te0)
    temp2<-NULL
    for(temp in 1:temp1)
      temp2<-cbind(temp2,te0)
    ie[[l]]<-temp2-denm[[l]]
    ie[[l]][,1:ncol(y)]=matrix(rep(te0,ncol(y)),ncol=ncol(y))-denm1[[l]]      #the total indirect effect
    te=cbind(te,ie[[l]][,1:ncol(y)]+denm[[l]][,1:ncol(y)])                    #the total effect
    if(!is.null(listm$multi)) 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    if(!is.null(listm$multi))
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    }
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
    names(denm)<-pred_names[dirx1]
    names(ie)<-pred_names[dirx1]
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear,Survival=surv, type=type, model=full.model,best.iter=best.iter1),pred.new=pred.new,w.new=w.new,data=data,distmgivenx=distmgivenx)
    class(a)<-"med"
    return(a)
  }
  
  anymissing<-function(vec)
  {if(sum(is.na(vec))>0)
    return(F)
    else return(T)
  }
  
  if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")

  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  ynames=colnames(y)
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else 
      cova_names=colnames(cova[[1]])}
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(binm))
    binm<-unlist(sapply(binm,grep,xnames))
  if(!is.null(catm))
    for (i in 2:length(catm))
      if(is.character(catm[[i]]))
        catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  #set.seed(seed)
  
  if(is.null(catm))
  {multi=jointm
  name1<-NULL                       #added in the new program
  if (!is.null(multi))              #added in the new program, in case that multi is NULL
    name1<-paste("j",1:multi[[1]],sep="")}
  else if(is.null(jointm))
  {multi=catm
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])}
  else {temp1<-catm
  temp2<-jointm
  temp1[[1]]=catm[[1]]+jointm[[1]]
  temp2[[1]]<-NULL
  multi=append(temp1,temp2)
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])
  name1<-c(name1,paste("j",1:jointm[[1]],sep=""))} 
  listm=list(single=c(contm,binm),multi=multi)
  
  ny=ncol(y)
  nx=length(dirx1)
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  mul<-ifelse(is.null(multi),0,multi[[1]])        #added in the new program, in case multi is null
  ie<-matrix(0,n2,ny*(1+length(listm$single)+mul))   #added in the new program
  ie1<-matrix(0,nx,ny*(1+length(listm$single)+mul))   #added in the new program
  if(!is.null(listm$multi))
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  rownames(ie1)<-pred_names[dirx1]}
  else 
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  rownames(ie1)<-pred_names[dirx1]}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names[dirx1]
  
  temp.med<-med.contx(data=NULL,x=x,y=y,dirx=dirx, dirx1=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova, 
                      margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,distn=distn,family1=family1,biny=biny,
                      refy=refy,x.new=x.new,pred.new=pred.new, cova.new=cova.new, surv=surv,type=type,w=w,w.new=w.new,
                      xmod=xmod,custom.function = custom.function)
  temp=temp.med
  temp.1<-NULL
  for (l in 1:nx)
    temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  if(is.null(w.new))
  {te[1,]<-apply(temp$te,2,mean,na.rm=T)
  de[1,]<-apply(temp.1,2,mean,na.rm=T) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
  }
  else
  {te[1,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
  de[1,]<-apply(temp$denm[,1],2,weighted.mean,na.rm=T,w=w.new) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T,w=w.new)  #first row is the estimated value
  }
  
  
  te1<-NULL                      #to store the mediation effects on predictor
  de1<-NULL
  ie2<-rep(list(NULL),nx)
  names(ie2)<-pred_names[dirx1]
  model<-temp$model
  all_model=NULL
  all_iter=NULL
  all_boot=NULL
  
  for (i in 1:n2)
  {boots<-sample(1:nrow(x),replace=T, prob=w)
  x1<-data.frame(x[boots,])
  colnames(x1)=xnames
  y1<-data.frame(y[boots,])
  colnames(y)=ynames
  dirx1.temp<-data.frame(dirx[boots,])
  colnames(dirx1.temp)=pred_names
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
    {cova1<-data.frame(cova[boots,])
    colnames(cova1)=cova_names}
    else 
    {cova1=cova
    cova1[[1]]=data.frame(cova[[1]][boots,])
    colnames(cova1[[1]])=cova_names
    names(cova1[[1]])=names(cova[[1]])}}
  else
    cova1=NULL
  temp<-med.contx(data=NULL,x=x1,y=y1,dirx=dirx1.temp,dirx1=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova1, 
                  margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,
                  distn=distn,family1=family1,biny=biny,refy=refy,x.new=x.new,pred.new=pred.new,cova.new=cova.new,surv=surv,
                  type=type,xmod=xmod,custom.function = custom.function) #added to the new codel, change the seed to make different results
  if(all.model)
  {all_model[[i]]=temp$model$model
  all_iter=rbind(all_iter,temp$model$best.iter)
  all_boot=rbind(all_boot,boots)}
  temp.1<-NULL
  for (l in 1:nx)
    temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  if(is.null(w.new))
  {te[1+i,]<-apply(temp$te,2,mean,na.rm=T)
  de[1+i,]<-apply(temp.1,2,mean,na.rm=T)
  for (l in 1:nx)
    ie[[l]][i,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
  }
  else
  {te[1+i,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
  de[1+i,]<-apply(temp$denm[,1],weighted.mean,na.rm=T,w=w.new)
  for (l in 1:nx)
    ie[[l]][i,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T)  #first row is the estimated value
  }
  te1<-cbind(te1,temp$te)
  de1<-cbind(de1,temp.1)
  for (l in 1:nx)
    ie2[[l]]<-rbind(ie2[[l]],temp$ie[[l]])
  print(i)
  }
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names[dirx1],each=ncol(y)),sep=".")
  missing.pred.new<-apply(data.frame(pred.new),1,anymissing)
  pred.new<-data.frame(pred.new[missing.pred.new,])
  
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model,
          data=list(x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm, jointm=jointm, cova=cova, binpred=NULL,
                    contpred=dirx1,catpred=NULL),
          boot.detail=list(pred.new=pred.new,cova.new=cova.new,te1=te1,de1=de1,ie1=ie2),w.new=w.new,
          all_model=all_model,all_iter=all_iter,all_boot=all_boot,mod=F,med=temp.med)
  class(a)<-"mma"
  return(a)
}

data<-data.org(x=x,y=y,pred=pred,mediator=mediator,contmed=contmed,binmed=binmed,
               binref=binref,catmed=catmed,catref=catref,jointm=jointm,cova=cova,refy=refy,family1=family1,
               predref=predref,alpha=alpha,alpha2=alpha2,testtype=testtype, w=w)

if(!is.null(data$bin.results))
{biny=data$bin.results$y_type==2
 surv=data$bin.results$y_type==4
 y_type=data$bin.results$y_type
 y=data$bin.results$y
 family1=data$bin.results$family1}
else
{biny=data$cont.results$y_type==2
 surv=data$cont.results$y_type==4
 y_type=data$cont.results$y_type
 y=data$cont.results$y
 family1=data$cont.results$family1}

if(sum(surv)>0 & is.null(type) & nonlinear)
  type="response"
else if (sum(surv)>0 & is.null(type))
  type="risk"
if(is.null(distn))
  distn<-rep(NA,ncol(y))
distn[is.na(distn) & y_type==2]="bernoulli"
distn[is.na(distn) & y_type==4]="coxph"
distn[is.na(distn) & y_type==1]="gaussian"

a.binx=NULL
a.contx=NULL

if(!is.null(data$bin.results)) 
  {a.binx<-boot.med.binx(data=data$bin.results,n=n,n2=n2,nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                         w=w,biny=biny,refy=rep(0,ncol(y)),surv=surv,type=type,all.model=all.model,xmod=xmod,custom.function=custom.function)
  }

if(!is.null(data$cont.results))
  {if(is.null(pred.new))
    a.contx<-boot.med.contx(data=data$cont.results,margin=margin, n=n,nonlinear=nonlinear,df1=df1, nu=nu,D=D,distn=distn,
                           family1=family1,n2=n2,w=w,biny=biny,refy=rep(0,ncol(y)),surv=surv,type=type,
                           all.model=all.model,xmod=xmod,custom.function=custom.function)
   else
    a.contx<-boot.med.contx(data=data$cont.results,margin=margin, n=n,nonlinear=nonlinear,df1=df1, nu=nu,D=D,distn=distn,family1=family1,
                           n2=n2,w=w,biny=biny,refy=0, x.new=x.new, pred.new=pred.new,cova.new=cova.new,surv=surv,type=type,
                           w.new=w.new,all.model=all.model,xmod=xmod,custom.function=custom.function)
  }
a<-list(a.binx=a.binx, a.contx=a.contx)
class(a)<-"mma"
return(a)
}


#classes and methods for mma
print.mma<-function(x,...,digit=3)
{if(!is.null(x$a.binx))
{x1=x$a.binx
 cat("For Categorical Exposure(s): ")
 print(colnames(x$a.binx$data$dirx)[c(x$a.binx$data$binpred,unlist(x$a.binx$data$catpred))])
 cat("\n MMA Analysis: Estimated Mediation Effects Using ")
 if (x1$model$MART)
   cat ("MART\n")
 else cat("GLM\n")
 print(x1$e,digit=digit)}
  if(!is.null(x$a.contx))
  {x1=x$a.contx
  cat("For Continuous Exposure(s):\n")
  print(colnames(x$a.contx$data$dirx)[x$a.contx$data$contpred])
  cat("MMA Analysis: Estimated Mediation Effects Using ")
  if (x1$model$MART)
    cat ("MART\n")
  else cat("GLM\n")
  print(x1$e,digit=digit)}
}


summary.mma<-function(object,...,alpha=0.05,plot=TRUE,RE=FALSE,quant=F,ball.use=F,bymed=FALSE)
{ bin.result=NULL
 cont.result=NULL
  
 summary1<-function(object, alpha,plot,RE,quant,ball.use,bymed)
 {sqr.dist<-function(vec1,vec2,w)
 {weighted.mean((vec1-vec2)^2,w,na.rm=T)}

 bound.ball<-function(mat1,mat2)
 {upbd=rep(NA,ncol(mat1))
  lwbd=rep(NA,ncol(mat1))
  n1<-ncol(mat2)
  for(i in 1:n1)
  {temp.t<-i%%n1
   temp.z<-(1:ncol(mat1))%%n1==temp.t
   upbd[temp.z]<-apply(as.matrix(mat1[mat2[,i],temp.z]),2,max,na.rm=T)
   lwbd[temp.z]<-apply(as.matrix(mat1[mat2[,i],temp.z]),2,min,na.rm=T)
  }
  return(cbind(upbd,lwbd)) 
 }
 
 x<-object
 ny<-ncol(x$data$y)
 
 if(!x$mod)
   nx<-length(c(x$data$contpred,x$data$binpred,unlist(x$data$catpred)))
 else 
   nx<-length(x$moder.level$moder.level)#ncol(x$data$dirx)

 temp1<-x$boots
 temp2<-x$est
 
 temp3<-x$boots   #calculate the RE
 temp3$de<-temp3$de/temp3$te
 nie<-ncol(temp3$ie[[1]])/ny
 k<-0
 for(l in 1:nx)
   {temp.te<-as.matrix(temp3$te)[,(k+1):(k+ny)]
    temp.te1<-do.call(cbind, replicate(nie,temp.te,simplify=F))
    temp3$ie[[l]]<-temp3$ie[[l]]/temp.te1
    k<-k+ny
   }
 temp4<-x$est
 temp.te<-matrix(temp4$te,nx,ny,byrow=T)
 temp.te1<-do.call(cbind, replicate(nie,temp.te,simplify=F))
 temp4$ie<-temp4$ie/temp.te1
 temp4$de<-temp4$de/temp4$te
 
#find the confidence ball for each x and y combination
 ball<-NULL
 for (l in 1:nx)
   for (m in 1:ny)
   {temp.t<-m%%ny
    temp.z<-(1:ncol(x$bootsresults$ie[[l]]))%%ny==temp.t
    temp.z[1:ny]<-F
    if(!is.null(x$data$jointm$n))
      temp.z[(ncol(x$bootsresults$ie[[l]])-ny*x$data$jointm$n+1):ncol(x$bootsresults$ie[[l]])]<-F #delete the joint effect estimates
    temp.est<-c(x$estimation$de[(l-1)*ny+m], x$estimation$ie[l,temp.z])
    temp.boot<-cbind(as.matrix(x$bootsresults$de)[,(l-1)*ny+m],x$bootsresults$ie[[l]][,temp.z])
    temp.w<-1/apply(temp.boot,2,var)
    temp.dist<-apply(temp.boot,1,sqr.dist,temp.est,temp.w)
#    temp.rank<-rank(temp.dist)
    temp.ball<-temp.dist<quantile(temp.dist,1-alpha,na.rm=T) #temp.rank<=length(temp.dist)*(1-alpha)
    ball<-cbind(ball,temp.ball)
   }
colnames(ball)<-paste(rep(paste("x",1:nx,sep=""),each=ny),rep(paste("y",1:ny,sep=""),nx),sep=".") 
 
 a1<-alpha/2
 a2<-1-a1
 b1<-qnorm(a1)
 b2<-qnorm(a2)
 ie<-NULL
 for (l in 1:nx)
  {temp.bound<-bound.ball(temp1$ie[[l]],as.matrix(ball[,((l-1)*ny+1):(l*ny)]))
   ie[[l]]<-rbind(est=as.matrix(temp2$ie)[l,],mean=apply(temp1$ie[[l]],2,mean,na.rm=T),sd=apply(temp1$ie[[l]],2,sd,na.rm=T),
                 upbd=apply(temp1$ie[[l]],2,mean,na.rm=T)+b2*apply(temp1$ie[[l]],2,sd,na.rm=T),
                 lwbd=apply(temp1$ie[[l]],2,mean,na.rm=T)+b1*apply(temp1$ie[[l]],2,sd,na.rm=T),
                 upbd_q=apply(temp1$ie[[l]],2,quantile,a2,na.rm=T), lwbd_q=apply(temp1$ie[[l]],2,quantile,a1,na.rm=T),
                 upbd_b=temp.bound[,1], lwbd_b=temp.bound[,2])}
 names(ie)<-names(temp1$ie)
 
 temp.bound1<-bound.ball(as.matrix(temp1$te),as.matrix(ball))
 temp.bound2<-bound.ball(as.matrix(temp1$de),as.matrix(ball))
 temp1.result<-list(indirect.effect=ie,
                    total.effect=rbind(est=temp2$te,mean=apply(as.matrix(temp1$te),2,mean,na.rm=T),sd=apply(as.matrix(temp1$te),2,sd,na.rm=T),
                                   upbd=apply(as.matrix(temp1$te),2,mean,na.rm=T)+b2*apply(as.matrix(temp1$te),2,sd,na.rm=T),
                                   lwbd=apply(as.matrix(temp1$te),2,mean,na.rm=T)+b1*apply(as.matrix(temp1$te),2,sd,na.rm=T),
                                   upbd_q=apply(as.matrix(temp1$te),2,quantile,a2,na.rm=T),
                                   lwbd_q=apply(as.matrix(temp1$te),2,quantile,a1,na.rm=T),
                                   upbd_b=temp.bound1[,1],lwbd_b=temp.bound1[,2]),
                    direct.effect=rbind(est=temp2$de,mean=apply(as.matrix(temp1$de),2,mean,na.rm=T),sd=apply(as.matrix(temp1$de),2,sd,na.rm=T),
                                   upbd=apply(as.matrix(temp1$de),2,mean,na.rm=T)+b2*apply(as.matrix(temp1$de),2,sd,na.rm=T),
                                   lwbd=apply(as.matrix(temp1$de),2,mean,na.rm=T)+b1*apply(as.matrix(temp1$de),2,sd,na.rm=T),
                                   upbd_q=apply(as.matrix(temp1$de),2,quantile,a2,na.rm=T),
                                   lwbd_q=apply(as.matrix(temp1$de),2,quantile,a1,na.rm=T),
                                   upbd_b=temp.bound2[,1],lwbd_b=temp.bound2[,2]))
 
 ie<-NULL
   for (l in 1:nx)
   {temp.bound<-bound.ball(temp3$ie[[l]],as.matrix(ball[,((l-1)*ny+1):(l*ny)]))
    ie[[l]]<-rbind(est=as.matrix(temp4$ie)[l,],mean=apply(temp3$ie[[l]],2,mean,na.rm=T),sd=apply(temp3$ie[[l]],2,sd,na.rm=T),
                   upbd=apply(temp3$ie[[l]],2,mean,na.rm=T)+b2*apply(temp3$ie[[l]],2,sd,na.rm=T),
                   lwbd=apply(temp3$ie[[l]],2,mean,na.rm=T)+b1*apply(temp3$ie[[l]],2,sd,na.rm=T),
                   upbd_q=apply(temp3$ie[[l]],2,quantile,a2,na.rm=T), 
                   lwbd_q=apply(temp3$ie[[l]],2,quantile,a1,na.rm=T),
                   upbd_b=temp.bound[,1], lwbd_b=temp.bound[,2])}
 names(ie)<-names(temp3$ie)
 temp.bound2<-bound.ball(as.matrix(temp3$de),as.matrix(ball))
 temp2.result<-list(indirect.effect=ie,
                    direct.effect=rbind(est=temp4$de,mean=apply(as.matrix(temp3$de),2,mean,na.rm=T),sd=apply(as.matrix(temp3$de),2,sd,na.rm=T),
                                        upbd=apply(as.matrix(temp3$de),2,mean,na.rm=T)+b2*apply(as.matrix(temp3$de),2,sd,na.rm=T),
                                        lwbd=apply(as.matrix(temp3$de),2,mean,na.rm=T)+b1*apply(as.matrix(temp3$de),2,sd,na.rm=T),
                                        upbd_q=apply(as.matrix(temp3$de),2,quantile,a2,na.rm=T),
                                        lwbd_q=apply(as.matrix(temp3$de),2,quantile,a1,na.rm=T),
                                        upbd_b=temp.bound2[,1],lwbd_b=temp.bound2[,2]))
 result<-list(results=temp1.result,re=temp2.result,alpha=alpha,plot=plot,obj=x,RE=RE,quant=quant,nx=nx,nie=nie,ny=ny,ball.use=ball.use,bymed=bymed)
 result
 }
 
 if(!is.null(object$a.contx))
   cont.result=summary1(object$a.contx, alpha,plot,RE,quant,ball.use,bymed)
 if(!is.null(object$a.binx))
   bin.result=summary1(object$a.binx, alpha,plot,RE,quant,ball.use,bymed)
 result=list(bin.result=bin.result, cont.result=cont.result)
 class(result)<-"summary.mma"
 result
 }

print.summary.mma<-function(x,...,digit=3)
{ print1<-function(x,digit)
{cat("MMA Analysis: Estimated Mediation Effects Using ")
 if (x$obj$model$MART)
  cat ("MART\n")
 else cat("GLM\n")
 pred.names<-names(x$result$indirect.effect) 
 
 gen.matrix<-function(matr,l)
 {return(matr[,l])}
 if(x$bymed){
   nmed=ncol(x$results$indirect.effect[[1]])
   med_names=colnames(x$results$indirect.effect[[1]])
   temp.res=NULL
   if(x$RE)
   {cat("The relative effects:\n")
     print(apply(x$re$direct.effect,2,round,digit))
     for (l in 1:nmed)
     {cat ("For Mediator",med_names[l],"\n")
       temp.res[[l]]<-matrix(unlist(lapply(x$re$indirect.effect,gen.matrix,l)),9)
       colnames(temp.res[[l]])=names(x$re$indirect.effect)
       rownames(temp.res[[l]])=rownames(x$re$indirect.effect[[1]])
       print(apply(temp.res[[l]],2,round,digit))
     }
   }
   else{
     print(apply(x$results$total.effect,2,round,digit))
     print(apply(x$results$direct.effect,2,round,digit))
     for (l in 1:nmed)
     {cat ("For Mediator",med_names[l],"\n")
       temp.res[[l]]<-matrix(unlist(lapply(x$results$indirect.effect,gen.matrix,l)),9)
       colnames(temp.res[[l]])=names(x$results$indirect.effect)
       rownames(temp.res[[l]])=rownames(x$results$indirect.effect[[1]])
       print(apply(temp.res[[l]],2,round,digit))
     }}
   
   if(x$plot)
   {if(x$RE)
   {re<-x$re$direct.effect[2,]
   if(x$ball.use)
   {re<-x$re$direct.effect[1,]  # ball is more likely to centered around the est but not mean
   upper<-x$re$direct.effect[8,]
   lower<-x$re$direct.effect[9,]}
   else if(x$quant)
   {upper<-x$re$direct.effect[6,]
   lower<-x$re$direct.effect[7,]}
   else
   {upper<-x$re$direct.effect[4,]
   lower<-x$re$direct.effect[5,]}
   name1<-colnames(x$re$direct.effect)
   par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
   bp <- barplot2(re, horiz = TRUE, main=paste("Relative Direct Effect"), 
                  names.arg=name1,plot.ci = TRUE, ci.u = upper, ci.l = lower,
                  cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower),na.rm=T),
                  col = rainbow(length(re), start = 3/6, end = 4/6))
   }
     else
     {re<-x$results$total.effect[2,]
     if(x$ball.use)
     {re<-x$results$total.effect[1,]  # ball is more likely to centered around the est but not mean
     upper<-x$results$total.effect[8,]
     lower<-x$results$total.effect[9,]}
     else if(x$quant)
     {upper<-x$results$total.effect[6,]
     lower<-x$results$total.effect[7,]}
     else
     {upper<-x$results$total.effect[4,]
     lower<-x$results$total.effect[5,]}
     name1<-colnames(x$results$total.effect)
     par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
     bp <- barplot2(re, horiz = TRUE, main=paste("Total Effect"), 
                    names.arg=name1,plot.ci = TRUE, ci.u = upper, ci.l = lower,
                    cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower),na.rm=T),
                    col = rainbow(length(re), start = 3/6, end = 4/6))
     
     re<-x$results$direct.effect[2,]
     if(x$ball.use)
     {re<-x$results$direct.effect[1,]  # ball is more likely to centered around the est but not mean
     upper<-x$results$direct.effect[8,]
     lower<-x$results$direct.effect[9,]}
     else if(x$quant)
     {upper<-x$results$direct.effect[6,]
     lower<-x$results$direct.effect[7,]}
     else
     {upper<-x$results$direct.effect[4,]
     lower<-x$results$direct.effect[5,]}
     name1<-colnames(x$results$direct.effect)
     par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
     bp <- barplot2(re, horiz = TRUE, main=paste("Direct Effect"), 
                    names.arg=name1,plot.ci = TRUE, ci.u = upper, ci.l = lower,
                    cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower),na.rm = T),
                    col = rainbow(length(re), start = 3/6, end = 4/6))
     }
     
     for (l in 1:nmed)
     {re<-temp.res[[l]][2,]
     if(x$ball.use)
     {re<-temp.res[[l]][1,]  # ball is more likely to centered around the est but not mean
     upper<-temp.res[[l]][8,]
     lower<-temp.res[[l]][9,]}
     else if(x$quant)
     {upper<-temp.res[[l]][6,]
     lower<-temp.res[[l]][7,]}
     else
     {upper<-temp.res[[l]][4,]
     lower<-temp.res[[l]][5,]}
     name1<-colnames(temp.res[[l]])
     par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
     bp <- barplot2(re, horiz = TRUE, main=paste("Indirect Effects of",med_names[l], "on y"), 
                    names.arg=name1,plot.ci = TRUE, ci.u = upper, ci.l = lower,
                    cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower),na.rm=T),
                    col = rainbow(length(re), start = 3/6, end = 4/6))
     }
   }
 }
 else{
 if(x$RE)
 {cat("The relative effects:\n")
   for (l in 1:x$nx)
   {cat ("For Predictor/Moderator at",pred.names[l],"\n")
     temp.res<-list(direct.effect=x$re$direct.effect[,(x$ny*(l-1)+1):(x$ny*(l-1)+x$ny)],
                    indirect.effect=x$re$indirect.effect[[l]])
     print(lapply(temp.res,round,digit))
   }
 }
 else  
  for (l in 1:x$nx)
  {cat ("For Predictor/Moderator at",pred.names[l],"\n")
   temp.res<-list(total.effect=x$result$total.effect[,(x$ny*(l-1)+1):(x$ny*(l-1)+x$ny)],
                  direct.effect=x$result$direct.effect[,(x$ny*(l-1)+1):(x$ny*(l-1)+x$ny)],
                  indirect.effect=x$result$indirect.effect[[l]])
   print(lapply(temp.res,round,digit))
  }
 
if(x$plot)
if(x$RE)
 for (l in 1:x$nx)
  for (m in 1:x$ny)
  {temp.t<-m%%x$ny
   temp.z<-(1:ncol(x$re$indirect.effect[[l]]))%%x$ny==temp.t
   temp.z[1:x$ny]<-F
   re<-c(x$re$indirect.effect[[l]][2,temp.z],x$re$dir[2,x$ny*(l-1)+m])
   if(x$ball.use)
   {re<-c(x$re$indirect.effect[[l]][1,temp.z],x$re$dir[1,x$ny*(l-1)+m])  # ball is more likely to centered around the est but not mean
    upper<-c(x$re$indirect.effect[[l]][8,temp.z],x$re$dir[8,x$ny*(l-1)+m])
    lower<-c(x$re$indirect.effect[[l]][9,temp.z],x$re$dir[9,x$ny*(l-1)+m])}
   else if(x$quant)
   {upper<-c(x$re$indirect.effect[[l]][6,temp.z],x$re$dir[6,x$ny*(l-1)+m])
    lower<-c(x$re$indirect.effect[[l]][7,temp.z],x$re$dir[7,x$ny*(l-1)+m])}
   else
    {upper<-c(x$re$indirect.effect[[l]][4,temp.z],x$re$dir[4,x$ny*(l-1)+m])
     lower<-c(x$re$indirect.effect[[l]][5,temp.z],x$re$dir[5,x$ny*(l-1)+m])}
   d<-order(re)
   name1<-c(colnames(x$re$indirect.effect[[l]])[temp.z],"de")
   par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
   bp <- barplot2(re[d], horiz = TRUE, main=paste("Relative Effects on y",m," on Predictor/Moderator at ",pred.names[l],sep=""), 
                names.arg=name1[d],plot.ci = TRUE, ci.u = upper[d], ci.l = lower[d],
                cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower),na.rm=T),
                col = rainbow(length(re), start = 3/6, end = 4/6))
  }
else
  for (l in 1:x$nx)
    for (m in 1:x$ny)
    {temp.t<-m%%x$ny
     temp.z<-(1:ncol(x$results$indirect.effect[[l]]))%%x$ny==temp.t
     temp.z[1:x$ny]<-F
     results<-c(x$results$indirect.effect[[l]][2,temp.z],x$results$dir[2,x$ny*(l-1)+m])
     temp.tot<-x$results$tot[2,x$ny*(l-1)+m]
    if(x$ball.use)
    {results<-c(x$results$indirect.effect[[l]][1,temp.z],x$results$dir[1,x$ny*(l-1)+m]) #ball based on est
     upper<-c(x$results$indirect.effect[[l]][8,temp.z],x$results$dir[8,x$ny*(l-1)+m])
     lower<-c(x$results$indirect.effect[[l]][9,temp.z],x$results$dir[9,x$ny*(l-1)+m])
     upper.tot<-x$results$tot[8,x$ny*(l-1)+m]
     lower.tot<-x$results$tot[9,x$ny*(l-1)+m]}
    else if(x$quant)
    {upper<-c(x$results$indirect.effect[[l]][6,temp.z],x$results$dir[6,x$ny*(l-1)+m])
     lower<-c(x$results$indirect.effect[[l]][7,temp.z],x$results$dir[7,x$ny*(l-1)+m])
     upper.tot<-x$results$tot[6,x$ny*(l-1)+m]
     lower.tot<-x$results$tot[7,x$ny*(l-1)+m]}
    else
    {upper<-c(x$results$indirect.effect[[l]][4,temp.z],x$results$dir[4,x$ny*(l-1)+m])
     lower<-c(x$results$indirect.effect[[l]][5,temp.z],x$results$dir[5,x$ny*(l-1)+m])
     upper.tot<-x$results$tot[4,x$ny*(l-1)+m]
     lower.tot<-x$results$tot[5,x$ny*(l-1)+m]}
    d<-order(results)
    name1<-c(colnames(x$results$indirect.effect[[l]])[temp.z],"de")
    par(mfrow=c(1,1),mar=c(1,6,1,1),oma=c(3,2,2,4))
    bp <- barplot2(c(results[d],temp.tot), horiz = TRUE, main=paste("Mediation Effects on y",m," on Predictor/Moderator at ",pred.names[l],sep=""), 
                   names.arg=c(name1[d],"total"),plot.ci = TRUE, ci.u = c(upper[d],upper.tot), ci.l = c(lower[d],lower.tot),
                   cex.names=0.9,beside=FALSE,cex.axis=0.9,las=1,xlim=range(c(upper,lower,upper.tot,lower.tot),na.rm=T),
                   col = rainbow(length(d)+1, start = 3/6, end = 4/6))
    }
}
}
if(!is.null(x$bin.result))
  print1(x$bin.result,digit)
if(!is.null(x$cont.result))
  print1(x$cont.result,digit)
}

plot.mma<-function(x,...,vari,xlim=NULL,alpha=0.95,quantile=F)
{plot1.mma<-function(x,vari,xlim,alpha,quantile){
marg.den<-function(x,y,w=NULL) #added w
{if(!is.null(w))
  w<-w[!is.na(x) & !is.na(y)]
y<-y[!is.na(x)]
x<-x[!is.na(x)]
x<-x[!is.na(y)]
y<-y[!is.na(y)]
z1<-unique(x)
z2<-rep(0,length(z1))
if(is.null(w))   #
  for (i in 1:length(z1))
    z2[i]<-mean(y[x==z1[i]],na.rm=T)  
else          #
  for (i in 1:length(z1))      #
    z2[i]<-weighted.mean(y[x==z1[i]],w[x==z1[i]],na.rm=T)  #added ,w[x==z1[i]]
z3<-order(z1)
cbind(z1[z3],z2[z3])
}

weighted.hist<-function (x, w, breaks = "Sturges", col = NULL, plot = TRUE, 
                         freq = TRUE, ylim = NA, ylab = NULL, xaxis = TRUE, ...) 
{
  if (missing(x)) 
    stop("Usage: weighted.hist(x,...) vector of values x required")
  if (missing(w)) 
    w <- rep(1, length(x))
  breaks <- get.breaks(x, breaks)
  width <- diff(breaks)
  diffx <- diff(range(x))
  equidist <- sum(width - width[1]) < diffx/1000
  nbreaks <- length(breaks) - 1
  lastbreak <- breaks[nbreaks + 1]
  breaks[nbreaks + 1] <- breaks[nbreaks + 1] + diffx/1000
  if (diff(range(breaks)) < diffx) 
    warning("Not all values will be included in the histogram")
  counts <- rep(0, nbreaks)
  for (bin in 1:nbreaks) counts[bin] <- sum(w[x >= breaks[bin] & 
                                                x < breaks[bin + 1]])
  density <- counts/sum(counts)
  if (freq) {
    if (is.null(ylab)) 
      ylab <- "Frequency"
    heights <- counts
    if (!equidist) 
      warning("Areas will not relate to frequencies")
  }
  else {
    if (!equidist) {
      heights <- density * mean(width)/width
      heights <- heights/sum(heights)
    }
    else heights <- density
    if (is.null(ylab)) 
      ylab <- "Density"
  }
  if (plot) {
    if (is.null(col)) 
      col <- par("bg")
    if (is.na(ylim)) 
      ylim <- c(0, 1.1 * max(heights, na.rm = TRUE))
    mids <- barplot(heights, width = width, col = col, space = 0, 
                    ylim = ylim, ylab = ylab, ...)
    tickpos <- c(mids - width/2, mids[length(mids)] + width[length(width)]/2)
    if (xaxis) 
      axis(1, at = tickpos, labels = signif(c(breaks[1:nbreaks], 
                                              lastbreak), 3))
  }
  else mids <- breaks[-length(breaks)] + width/2
  invisible(list(breaks = breaks, counts = counts, density = density, 
                 mids = mids, xname = deparse(substitute(x)), equidist = equidist))
}

get.breaks<-function (x, breaks) 
{
  if (is.character(breaks)) 
    nbreaks <- do.call(paste("nclass", breaks, sep = ".", 
                             collapse = ""), list(x))
  if (is.numeric(breaks)) {
    if (length(breaks) == 1) {
      nbreaks <- breaks
    }
    else return(breaks)
  }
  breakinc <- diff(range(x))/nbreaks
  breaks <- c(min(x), rep(breakinc, nbreaks))
  breaks <- cumsum(breaks)
  return(breaks)
}

overlapHist <- function(a, b,breaks=NULL, xlim=NULL, xname=NULL, w=NULL)
{if(ncol(b)>1)
  {d<-rep(0,length(b))
   for (l in 1:ncol(b))
     d[b[,l]==1]<-l
   b<-d}
a1<-a
b1<-b
a<-a[!is.na(a1) & !is.na(b1)]
b<-b[!is.na(a1) & !is.na(b1)]
if(!is.null(w))                     #
  w<-w[!is.na(a1) & !is.na(b1)]    #
j<-sort(unique(b))
ahist<-hist(a[b==j[1]],plot=F)
if(!is.null(w))                     #
  ahist<-weighted.hist(a[b==j[1]], w[b==j[1]], plot=F)    #
dist = ahist$breaks[2]-ahist$breaks[1]
lb =min(ahist$breaks,na.rm = T)
ub=max(ahist$breaks,na.rm = T)
yl=max(ahist$density,na.rm = T)
for(i in j[-1])
{bhist<-hist(a[b==i],plot=F)
lb =min(lb,bhist$breaks,na.rm = T)
ub =max(ub,bhist$breaks,na.rm = T)
yl=max(yl,bhist$density,na.rm = T)
dist = min(dist,bhist$breaks[2]-bhist$breaks[1])
}
breaks=seq(lb,ub,dist)
if(is.null(xlim))
  xlim=c(lb,ub)

if(is.null(w))                     #
  for (i in j)
    hist(a[b==i],ylab="Density",xlab="",breaks=breaks, 
         xlim=xlim, ylim=c(0,yl), freq=F,main=paste(xname,i,sep="="))
else           #
  for (i in j) #
    weighted.hist(a[b==i],w[b==i],ylab="Density",xlab="",breaks=breaks, #
                  xlim=xlim, ylim=c(0,yl), freq=F,main=paste(xname,i,sep="=")) #
}

weighted.prop.table<-function(x,w)  #the whole function is added for weighted proportions
{sumw<-sum(w[!is.na(x)],na.rm=T)
temp<-sort(unique(x))
table<-rep(0,length(temp))
names(table)<-temp
j<-1
for(temp1 in temp)
{table[j]<-sum(w[x==temp1],na.rm=T)/sumw
j<-j+1}
table
}

boot.ci<-function(x,mat,alpha,quantile=F) #the mat is the booted results with row be different x, and columns diff boot
  #cri_val is the critical value
{x.uniq<-sort(unique(x,na.rm=T))
mn<-NULL
upbd<-NULL
lwbd<-NULL
alpha<-(1-alpha)/2
for (i in x.uniq)
{sd_dev<-sd(as.vector(mat[x==i,]),na.rm=T)
mn1<-mean(as.vector(mat[x==i,]),na.rm=T)
if(quantile)
{upbd<-c(upbd,quantile(as.vector(mat[x==i,]),1-alpha,na.rm=T))
lwbd<-c(lwbd,quantile(as.vector(mat[x==i,]),alpha,na.rm=T))
}
else
{cri_val<-qnorm(1-alpha)
upbd<-c(upbd,mn1+cri_val*sd_dev)
lwbd<-c(lwbd,mn1-cri_val*sd_dev)}
mn<-c(mn,mn1)}
x.uniq<-x.uniq[!is.na(lwbd)&!is.na(upbd)]
tt<-(!is.na(lwbd)) & (!is.na(upbd))
mn<-mn[tt]
lwbd<-lwbd[tt]
upbd<-upbd[tt]
return(data.frame(x=x.uniq,F=mn,L=lwbd,U=upbd))
}

plot_ci<-function(df1,xlab="x",ylab="IE")
{plot(df1$x, df1$F, ylim = range(c(df1$L,df1$U),na.rm=T), type = "l",xlab=xlab,ylab=ylab)
  polygon(c(df1$x,rev(df1$x)),c(df1$L,rev(df1$U)),col = "grey75", border = FALSE)
  lines(df1$x, df1$F, lwd = 2)
  lines(df1$x, df1$U, col="red",lty=2)
  lines(df1$x, df1$L, col="red",lty=2)}

nx<-length(c(x$data$binpred,x$data$contpred,unlist(x$data$catpred)))
ny<-ncol(x$data$y)
op <- par(no.readonly = TRUE) # the whole list of settable par's.
data=x$data
pred_name=colnames(x$data$dirx)
mname<-ifelse(is.character(vari),vari,names(data$x)[vari])
vari=mname
if(is.null(xlim) & !is.factor(x$data$x[,grep(vari,names(x$data$x))]))
   xlim=range(x$data$x[,grep(vari,colnames(x$data$x))],na.rm=T)

if (x$model[1]==T) 
 for (m in 1:ny) {
  full.model=x$model$model[[m]]
  best.iter=x$model$best.iter[m]
  if(is.null(x$data$contpred)) #for binary or categorical predictors
   {if(!is.factor(data$x[,vari]))
     {if(full.model$distribution=="gaussian")
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim)))
      else if(full.model$distribution=="coxph")
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,xlim=xlim)))
      else
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim,type="response")))
     
     par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
      if(is.null(data$binpred))
        for (z.b in data$binpred)
           overlapHist(a=data$x[,vari],b=as.matrix(data$dirx[,z.b]),xlim=xlim,xname=pred_name[,z.b],w=data$w) # added w
           
      if(is.null(data$catpred))
        for (z.c in 1:length(data$catpred))
         {d<-rep(0,nrow(data$dirx))
          for(l in 1:length(data$catpred[[z.c]]))
            d[data$dirx[,l]==1]<-l
          par(mfrow=c(l+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
          overlapHist(a=data$x[,vari],b=as.matrix(d),xlim=xlim,xname=paste("Categorital Predictor",l, sep="."),w=data$w)
        }
     }
   else{
    if(full.model$distribution=="gaussian")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,type="response")))
     
    if (is.null(data$w)) #
    {if(!is.null(data$binpred))
      for (z.b in data$binpred)
       {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        temp1<-prop.table(table(data$x[data$dirx[,z.b]==0,vari]))
        temp1<-c(temp1,prop.table(table(data$x[data$dirx[,z.b]==1,vari])))
        barplot(prop.table(table(data$x[data$dirx[,z.b]==0,vari])),ylim=c(0,max(temp1,na.rm=T)),
             ylab="Prop",sub=paste(pred_name[z.b], "at the Reference Level: pred=",0,sep=""))     
        barplot(prop.table(table(data$x[data$dirx[,z.b]==1,vari])),ylim=c(0,max(temp1,na.rm=T)),
             ylab="Prop",sub=paste(colnames(data$dirx)[z.b], ", pred=",1,sep=""))}
     if(!is.null(data$catpred))
        for (z.c in 1:length(data$catpred))
        {par(mfrow=c(length(data$catpred[[z.c]])+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
          temp1<-prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,vari]))
          for (j in data$catpred[[z.c]])
            temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,vari])))
          barplot(prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,vari])),
                  ylim=c(0,max(temp1,na.rm=T)),
                  ylab="Prop",sub=paste("Categorical Predictor", z.c, "at the Reference Level: pred=",0,sep=""))  
          for (j in data$catpred[[z.c]])
            barplot(prop.table(table(data$x[data$dirx[,j]==1,vari])),ylim=c(0,max(temp1,na.rm=T)),
                    ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=",j,sep=""))   
        }
    }
    else #
    {if(!is.null(data$binpred))
      for (z.b in data$binpred)
      {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        temp1<-        weighted.prop.table(data$x[data$dirx[,z.b]==0,vari],data$w)
        temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,z.b]==1,vari],data$w))#
        barplot(weighted.prop.table(data$x[data$dirx[,z.b]==0,vari]),ylim=c(0,max(temp1,na.rm=T)),#
             ylab="Prop",sub=paste(pred_name[z.b], "at the Reference Level: pred=",0,sep=""))
        barplot(weighted.prop.table(data$x[data$dirx[,z.b]==1,vari]),ylim=c(0,max(temp1,na.rm=T)),#
              ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=", j,sep=""))}
      if(!is.null(data$catpred))
        for (z.c in 1:length(data$catpred))
        {par(mfrow=c(length(data$catpred[[z.c]])+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
          temp1<-c(temp1,weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,vari],data$w))#
          for (j in data$catpred[[z.c]]) #
            temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,vari],data$w))#
          barplot(weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,vari]),ylim=c(0,max(temp1,na.rm=T)),#
                  ylab="Prop",sub=paste("Categorical Predictor", z.c, "at the Reference Level: pred=",0,sep=""))
          for (j in data$catpred[[z.c]])#
            barplot(weighted.prop.table(data$x[data$dirx[,j]==1,vari]),ylim=c(0,max(temp1,na.rm=T)),#
                    ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=", j,sep=""))}
  }
   }
  }
else
{par(mfrow=c(3,nx),mar=c(5,5,1,1),oma=c(3,2,5,4))
  for (l in data$contpred)
   {temp.ie.detail<-as.matrix(x$boot.detail$ie1[[l]][,grep(mname,colnames(x$boot.detail$ie1[[l]]))])  #
    ie1<-boot.ci(x$boot.detail$pred.new[,l],matrix(temp.ie.detail[,m],nrow=nrow(x$boot.detail$pred.new)),alpha,quantile)
    plot_ci(ie1,xlab=colnames(data$dirx)[l],ylab=paste("IE on",colnames(data$y)[m]))}
  if(!is.factor(data$x[,vari]))
  {if(full.model$distribution=="gaussian")
    suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,xlim=xlim)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim,type="response")))
    if(nx>1)
      for (i in 1:(nx-1))
        plot(1, type="n", axes=F, xlab="", ylab="")
    for(l in data$contpred){
    axis(1,at=data$x[,vari],labels=F)
    a<-marg.den(data$dirx[,l],data$x[,vari],data$w) #added data$w
    scatter.smooth(a[,1],a[,2],family="gaussian",xlab=colnames(data$dirx)[l],ylim=xlim,ylab=paste("Mean",mname,sep="."))}
  }
  else
  {if(full.model$distribution=="gaussian")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,type="response")))
    if(nx>1)
      for (i in 1:(nx-1))
        plot(1, type="n", axes=F, xlab="", ylab="")
    for(l in data$contpred){
      plot(data$x[,vari],data$dirx[,l],ylab=colnames(data$dirx)[l],xlab="")}}
}
}
else
  for (m in 1:ny) 
    {full.model=x$model$model[[m]]
     coef<-full.model$coefficients[grep(vari,names(full.model$coefficients))] #plot the straight line instead of the loess line
     if(is.null(full.model$na.action))
       {data1<-full.model$data[,grep(vari,names(full.model$data))]
        data.w=data$w}
     else
       {data1<-full.model$data[-full.model$na.action,grep(vari,names(full.model$data))]
        data.w=data$w[-full.model$na.action]}
     if(x$model$Survival[m] & is.null(x$model$best.iter)) #for cox model
     {if(is.null(full.model$na.action))
       {data1<-x$data$x[,vari]
        data.w=data$w}
      else {data1<-x$data$x[-full.model$na.action,vari]
            data.w=data$w[-full.model$na.action]}
     }
     if(is.null(data$contpred))
     {if(!is.factor(data$x[,grep(vari,names(data$x))]))
     {
       if(!x$model$Survival[m])
         b<-marg.den(data1,full.model$family$linkfun(full.model$fitted.values),data.w) #added data$w
       else
         b<-marg.den(data1,predict(full.model,type=x$model$type),data.w)  #added data$w
       plot(b,xlab=mname,ylab=paste("f(",mname,")",sep=""),xlim=xlim)
       abline(a=mean(b[,2],na.rm=T)-coef*mean(b[,1],na.rm=T),b=coef)
       axis(1,at=data1,labels=F)
       if(!is.null(data$binpred))
       {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
         for(j in data$binpred)
           overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(data$dirx[,j]),xlim=xlim,
                       xname=colnames(data$x)[j],data$w)  }
       if(!is.null(data$catpred))
         for(j in 1:length(data$catpred))
         {d<-rep(0,nrow(data$dirx))
         p=1
         for(l in data$catpred[[j]])
         {d[data$dirx[,l]==1]<-p
         p=p+1}
         par(mfrow=c(p,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
         overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(d),xlim=xlim,xname="Predictor",data$w)
         }        
       }
       else{par(mfrow=c(1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        # browser()
        if (!x$model$Survival[m])
          plot(full.model$fitted.values~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
        else
          plot(predict(full.model)~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
        temp1<-NULL
        if(is.null(data$w)){ #
          if(!is.null(data$binpred)){
            par(mfrow=c(length(data$binpred),2),mar=c(5,5,1,1),oma=c(3,2,5,4))
            for(j in data$binpred){
             temp1<-        prop.table(table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))]))
             temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])))
             barplot(prop.table(table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                   ylab="Prop",sub=paste(colnames(data$dirx)[j], "at the reference level",sep=" "))
             barplot(prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                     ylab="Prop",sub=colnames(data$dirx)[j])}}

          if(!is.null(data$catpred)){
            par(mfrow=c(1+nx,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
              for(z.c in 1:length(data$catpred)){
                temp1<-prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))]))
                for (j in data$catpred[[z.c]])
                  temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])))
                barplot(prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                        ylab="Prop",sub=paste("Categorical Predictor",z.c, "at the reference level",sep=" "))
                for (j in data$catpred[[z.c]])
                  barplot(prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                          ylab="Prop",sub=colnames(data$dirx)[j])
              }
              }
       }#
       else#
       {if(!is.null(data$binpred)){
         par(mfrow=c(length(data$binpred),2),mar=c(5,5,1,1),oma=c(3,2,5,4))
            for(j in data$binpred){
               temp1<-        weighted.prop.table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))],
                                              data$w[apply(data$dirx,1,sum)==0])
               temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                                  data$w[data$dirx[,j]==1]))#
               barplot(weighted.prop.table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))],
                                           data$w[apply(data$dirx!=0,1,sum)==0]),ylim=c(0,max(temp1)),#
                   ylab="Prop",sub=paste(colnames(data$dirx)[j],"at the reference level",sep=" ")) #
               barplot(weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                           data$w[data$dirx[,j]==1]),ylim=c(0,max(temp1)),#
                     ylab="Prop",sub=colnames(data$dirx)[j])}          
}
            if(!is.null(data$catpred)){
              par(mfrow=c(1+nx,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
              for(z.c in 1:length(data$catpred)){
                temp1<-weighted.prop.table(data$x[data$dirx[,data$catpred[[z.c]]]==0,grep(vari,names(data$x))],
                                           data$w[apply(data$dirx,1,sum)==0])
                for (j in data$catpred[[z.c]])#
                  temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                                     data$w[data$dirx[,j]==1]))#
                barplot(weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,
                                                   grep(vari,names(data$x))],data$w[apply(data$dirx!=0,1,sum)==0]),ylim=c(0,max(temp1)),#
                        ylab="Prop",sub="Predictor at the reference level") #
                for (j in data$catpred[[z.c]])#
                  barplot(weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],data$w[data$dirx[,j]==1]),ylim=c(0,max(temp1)),#
                          ylab="Prop",sub=colnames(data$dirx)[j])}} #
            
               } 
          }
      }
   else
    {par(mfrow=c(3,nx),mar=c(5,5,1,1),oma=c(3,2,5,4))
      for (l in data$contpred) {
         temp.ie.detail<-as.matrix(x$boot.detail$ie1[[l]][,grep(mname,colnames(x$boot.detail$ie1[[l]]))])  #
         ie1<-boot.ci(x$boot.detail$pred.new[,l],matrix(temp.ie.detail[,m],nrow=nrow(x$boot.detail$pred.new)),alpha,quantile)
         plot_ci(ie1,xlab=colnames(data$dirx)[l])}
      if(!is.factor(data$x[,grep(vari,names(data$x))]))
      {if(!x$model$Survival[m])
         b<-marg.den(data1,full.model$family$linkfun(full.model$fitted.values),data.w) #added data$w
       else
         b<-marg.den(data1,predict(full.model),data.w) #added data$w
       plot(b,xlab=mname,ylab=paste("f(",mname,")",sep=""),xlim=xlim)
       abline(a=mean(b[,2],na.rm=T)-coef*mean(b[,1],na.rm=T),b=coef)
       axis(1,at=data1,labels=F)
       if(nx>1)
         for (i in 1:(nx-1))
           plot(1, type="n", axes=F, xlab="", ylab="")
       for(l in data$contpred){
         a<-marg.den(data$dirx[,l],data$x[,grep(vari,colnames(data$x))],data$w)   #added data$w
         scatter.smooth(a[,1],a[,2],family="gaussian", xlab=colnames(data$dirx)[l],ylim=xlim,ylab=paste("Mean",mname,sep="."))}
      }
    else
     {if (!x$model$Survival[m])
        plot(full.model$fitted.values~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
      else  
        plot(predict(full.model,type=x$model$type)~data$x[-full.model$na.action,grep(vari,names(data$x))],ylab=paste("f(",mname,")",sep=""),xlab=mname)
      if(nx>1)
        for (i in 1:(nx-1))
          plot(1, type="n", axes=F, xlab="", ylab="")
      for(l in data$contpred){
         plot(data$x[,grep(vari,names(data$x))],data$dirx[,l],ylab=colnames(data$dirx)[l],xlab="")}}
}
}
par(op)
}

if(!is.null(x$a.binx))
 plot1.mma(x=x$a.binx,vari=vari,xlim=xlim,alpha=alpha,quantile=quantile)
if(!is.null(x$a.contx))
  plot1.mma(x=x$a.contx,vari=vari,xlim=xlim,alpha=alpha,quantile=quantile)
}

#plot on the med object
plot.med<-function(x,...,vari,xlim=NULL)#data is the result from data.org
{plot2<-function(x,vari,xlim,type){
  marg.den<-function(x,y,w=NULL) #added w
{if(!is.null(w))
  w<-w[!is.na(x) & !is.na(y)]
y<-y[!is.na(x)]
x<-x[!is.na(x)]
x<-x[!is.na(y)]
y<-y[!is.na(y)]
z1<-unique(x)
z2<-rep(0,length(z1))
if(is.null(w))   #
  for (i in 1:length(z1))
    z2[i]<-mean(y[x==z1[i]],na.rm=T)  
else          #
  for (i in 1:length(z1))      #
    z2[i]<-weighted.mean(y[x==z1[i]],w[x==z1[i]],na.rm=T)  #added ,w[x==z1[i]]
z3<-order(z1)
cbind(z1[z3],z2[z3])
}

weighted.hist<-function (x, w, breaks = "Sturges", col = NULL, plot = TRUE, 
                         freq = TRUE, ylim = NA, ylab = NULL, xaxis = TRUE, ...) 
{
  if (missing(x)) 
    stop("Usage: weighted.hist(x,...) vector of values x required")
  if (missing(w)) 
    w <- rep(1, length(x))
  breaks <- get.breaks(x, breaks)
  width <- diff(breaks)
  diffx <- diff(range(x))
  equidist <- sum(width - width[1]) < diffx/1000
  nbreaks <- length(breaks) - 1
  lastbreak <- breaks[nbreaks + 1]
  breaks[nbreaks + 1] <- breaks[nbreaks + 1] + diffx/1000
  if (diff(range(breaks)) < diffx) 
    warning("Not all values will be included in the histogram")
  counts <- rep(0, nbreaks)
  for (bin in 1:nbreaks) counts[bin] <- sum(w[x >= breaks[bin] & 
                                                x < breaks[bin + 1]])
  density <- counts/sum(counts)
  if (freq) {
    if (is.null(ylab)) 
      ylab <- "Frequency"
    heights <- counts
    if (!equidist) 
      warning("Areas will not relate to frequencies")
  }
  else {
    if (!equidist) {
      heights <- density * mean(width)/width
      heights <- heights/sum(heights)
    }
    else heights <- density
    if (is.null(ylab)) 
      ylab <- "Density"
  }
  if (plot) {
    if (is.null(col)) 
      col <- par("bg")
    if (is.na(ylim)) 
      ylim <- c(0, 1.1 * max(heights, na.rm = TRUE))
    mids <- barplot(heights, width = width, col = col, space = 0, 
                    ylim = ylim, ylab = ylab, ...)
    tickpos <- c(mids - width/2, mids[length(mids)] + width[length(width)]/2)
    if (xaxis) 
      axis(1, at = tickpos, labels = signif(c(breaks[1:nbreaks], 
                                              lastbreak), 3))
  }
  else mids <- breaks[-length(breaks)] + width/2
  invisible(list(breaks = breaks, counts = counts, density = density, 
                 mids = mids, xname = deparse(substitute(x)), equidist = equidist))
}

get.breaks<-function (x, breaks) 
{
  if (is.character(breaks)) 
    nbreaks <- do.call(paste("nclass", breaks, sep = ".", 
                             collapse = ""), list(x))
  if (is.numeric(breaks)) {
    if (length(breaks) == 1) {
      nbreaks <- breaks
    }
    else return(breaks)
  }
  breakinc <- diff(range(x))/nbreaks
  breaks <- c(min(x), rep(breakinc, nbreaks))
  breaks <- cumsum(breaks)
  return(breaks)
}

overlapHist <- function(a, b,breaks=NULL, xlim=NULL, xname=NULL, w=NULL)
{if(ncol(b)>1)
{d<-rep(0,length(b))
for (l in 1:ncol(b))
  d[b[,l]==1]<-l
b<-d}
  a1<-a
  b1<-b
  a<-a[!is.na(a1) & !is.na(b1)]
  b<-b[!is.na(a1) & !is.na(b1)]
  if(!is.null(w))                     #
    w<-w[!is.na(a1) & !is.na(b1)]    #
  j<-sort(unique(b))
  ahist<-hist(a[b==j[1]],plot=F)
  if(!is.null(w))                     #
    ahist<-weighted.hist(a[b==j[1]], w[b==j[1]], plot=F)    #
  dist = ahist$breaks[2]-ahist$breaks[1]
  lb =min(ahist$breaks,na.rm = T)
  ub=max(ahist$breaks,na.rm = T)
  yl=max(ahist$density,na.rm = T)
  for(i in j[-1])
  {bhist<-hist(a[b==i],plot=F)
  lb =min(lb,bhist$breaks,na.rm = T)
  ub =max(ub,bhist$breaks,na.rm = T)
  yl=max(yl,bhist$density,na.rm = T)
  dist = min(dist,bhist$breaks[2]-bhist$breaks[1])
  }
  breaks=seq(lb,ub,dist)
  if(is.null(xlim))
    xlim=c(lb,ub)
  if(is.null(w))                     #
    for (i in j)
      hist(a[b==i],ylab="Density",xlab="",breaks=breaks, 
           xlim=xlim, ylim=c(0,yl), freq=F,main=paste(xname,i,sep="="))
  else           #
    for (i in j) #
      weighted.hist(a[b==i],w[b==i],ylab="Density",xlab="",breaks=breaks, #
                    xlim=xlim, ylim=c(0,yl), freq=F,main=paste(xname,i,sep="=")) #
}


weighted.prop.table<-function(x,w)  #the whole function is added for weighted proportions
{sumw<-sum(w[!is.na(x)],na.rm=T)
temp<-sort(unique(x))
table<-rep(0,length(temp))
names(table)<-temp
j<-1
for(temp1 in temp)
{table[j]<-sum(w[x==temp1],na.rm=T)/sumw
j<-j+1}
table
}

data<-x$data
if(is.null(xlim)  & !is.factor(data$x[,grep(vari,names(data$x))]))
  xlim=range(data$x[,grep(vari,names(data$x))],na.rm=T)
op <- par(no.readonly = TRUE) # the whole list of settable par's.
nx<-length(x$ie)
ny<-ncol(data.frame(x$data$y))
mname<-ifelse(is.character(vari),vari,names(data$x)[vari])
pred_name<-colnames(data$dirx)

if (x$model[1]==T) 
 for (m in 1:ny) {
  full.model=x$model$model[[m]]
  best.iter=x$model$best.iter[m]
  if(type==1)
  {if(!is.factor(data$x[,grep(vari,names(data$x))]))
    {#browser()
     if(full.model$distribution=="gaussian")
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim)))
     else if(full.model$distribution=="coxph")
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,xlim=xlim)))
     else
        suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim,type="response")))
    
    par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
    if(is.null(data$binpred))
      for (z.b in data$binpred)
        overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(data$dirx[,z.b]),xlim=xlim,xname=pred_name[,z.b],w=data$w) # added w
    
    if(is.null(data$catpred))
      for (z.c in 1:length(data$catpred))
      {d<-rep(0,nrow(data$dirx))
      for(l in 1:length(data$catpred[[z.c]]))
        d[data$dirx[,l]==1]<-l
      par(mfrow=c(l+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
      overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(d),xlim=xlim,xname=paste("Categorital Predictor",l, sep="."),w=data$w)
      }
  }
  else{
    if(full.model$distribution=="gaussian")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,type="response")))
    
    if (is.null(data$w)) #
    {if(!is.null(data$binpred))
      for (z.b in data$binpred)
      {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        temp1<-prop.table(table(data$x[data$dirx[,z.b]==0,grep(vari,names(data$x))]))
        temp1<-c(temp1,prop.table(table(data$x[data$dirx[,z.b]==1,grep(vari,names(data$x))])))
        barplot(prop.table(table(data$x[data$dirx[,z.b]==0,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                ylab="Prop",sub=paste(pred_name[z.b], "at the Reference Level: pred=",0,sep=" "))     
        barplot(prop.table(table(data$x[data$dirx[,z.b]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                ylab="Prop",sub=paste(colnames(data$dirx)[z.b], ", pred=",1,sep=""))}
      if(!is.null(data$catpred))
        for (z.c in 1:length(data$catpred))
        {par(mfrow=c(length(data$catpred[[z.c]])+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
          temp1<-prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))]))
          for (j in data$catpred[[z.c]])
            temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])))
          barplot(prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))])),
                  ylim=c(0,max(temp1,na.rm=T)),
                  ylab="Prop",sub=paste("Categorical Predictor", z.c, "at the Reference Level: pred=",0,sep=""))  
          for (j in data$catpred[[z.c]])
            barplot(prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                    ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=",j,sep=""))   
        }
    }
    else #
    {if(!is.null(data$binpred))
      for (z.b in data$binpred)
      {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        temp1<-        weighted.prop.table(data$x[data$dirx[,z.b]==0,grep(vari,names(data$x))],data$w)
        temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,z.b]==1,grep(vari,names(data$x))],data$w))#
        barplot(weighted.prop.table(data$x[data$dirx[,z.b]==0,grep(vari,names(data$x))]),ylim=c(0,max(temp1,na.rm=T)),#
                ylab="Prop",sub=paste(pred_name[z.b], "at the Reference Level: pred=",0,sep=""))
        barplot(weighted.prop.table(data$x[data$dirx[,z.b]==1,grep(vari,names(data$x))]),ylim=c(0,max(temp1,na.rm=T)),#
                ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=", j,sep=""))}
      if(!is.null(data$catpred))
        for (z.c in 1:length(data$catpred))
        {par(mfrow=c(length(data$catpred[[z.c]])+1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
          temp1<-c(temp1,weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))],data$w))#
          for (j in data$catpred[[z.c]]) #
            temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],data$w))#
          barplot(weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))]),ylim=c(0,max(temp1,na.rm=T)),#
                  ylab="Prop",sub=paste("Categorical Predictor", z.c, "at the Reference Level: pred=",0,sep=""))
          for (j in data$catpred[[z.c]])#
            barplot(weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))]),ylim=c(0,max(temp1,na.rm=T)),#
                    ylab="Prop",sub=paste(colnames(data$dirx)[j], ", pred=", j,sep=""))}
    }  }
}
else
{par(mfrow=c(3,nx),mar=c(5,5,1,1),oma=c(3,2,5,4)) #test
  for (l in data$contpred){
  temp2<-data$dirx[,l]
  temp3<-as.matrix(x$ie[[l]][,grep(mname,colnames(x$ie[[l]]))])
  temp3<-temp3[,m]
  temp.order=order(temp2)
  plot(temp2[temp.order], temp3[temp.order],type="l",
       xlab=colnames(data$dirx)[l],ylab=paste(c("IE of", vari, "on", 
       colnames(data$y)[m]),sep=""))}
  
  if(!is.factor(data$x[,grep(vari,names(data$x))]))
  {if(full.model$distribution=="gaussian")
    suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,xlim=xlim)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,xlim=xlim,type="response")))
    if(nx>1)
      for (i in 1:(nx-1))
        plot(1, type="n", axes=F, xlab="", ylab="")
    for(l in data$contpred){
      axis(1,at=data$x[,grep(vari,names(data$x))],labels=F)
      a<-marg.den(data$dirx[,l],data$x[,grep(vari,names(data$x))],data$w) #added data$w
      scatter.smooth(a[,1],a[,2],family="gaussian",xlab=colnames(data$dirx)[l],ylim=xlim,ylab=paste("Mean",mname,sep="."))}
  }
  else
  {if(full.model$distribution=="gaussian")
    suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter)))
    else if(full.model$distribution=="coxph")
      suppressWarnings(print(plot.gbm(full.model, i.var=vari)))
    else
      suppressWarnings(print(plot.gbm(full.model, i.var=vari,best.iter,type="response")))
    if(nx>1)
      for (i in 1:(nx-1))
        plot(1, type="n", axes=F, xlab="", ylab="")
    for(l in data$contpred){
      plot(data$x[,grep(vari,names(data$x))],data$dirx[,l],ylab=colnames(data$dirx)[l],xlab="")}}
}
}
else
  for (m in 1:ny) 
  {full.model=x$model$model[[m]]
   coef<-full.model$coefficients[grep(vari, names(full.model$coefficients))] #plot the straight line instead of the loess line
   if(is.null(full.model$na.action))
     {data1<-full.model$data[,grep(vari,names(full.model$data))]
      data.w=data$w}
   else
     {data1<-full.model$data[-full.model$na.action,grep(vari,names(full.model$data))]
      data.w=data$w[-full.model$na.action]}
   if(x$model$Survival[m] & is.null(x$model$best.iter)) #for cox model
   {if(is.null(full.model$na.action))
     {data1<-x$data$x[,grep(vari,names(x$data$x))]
      data.w=data$w}
    else
    {data1<-x$data$x[-full.model$na.action,grep(vari,names(x$data$x))] 
     data.w=data$w[-full.model$na.action]}}
   if(type==1)
  {if(!is.factor(data$x[,grep(vari,names(data$x))]))
    {if(!x$model$Survival[m])
      b<-marg.den(data1,full.model$family$linkfun(full.model$fitted.values),data.w) # added w
     else
      b<-marg.den(data1,predict(full.model,type=x$model$type),data.w) #added w
     par(mfrow=c(1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
     plot(b,xlab=mname,ylab=paste("f(",mname,")",sep=""),xlim=xlim)
     abline(a=mean(b[,2])-coef*mean(b[,1]),b=coef)
     axis(1,at=data1,labels=F)
     
     if(!is.null(data$binpred))
     {par(mfrow=c(2,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
       for(j in data$binpred)
         overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(data$dirx[,j]),xlim=xlim,
                     xname=colnames(data$x)[j],data$w)  }
     if(!is.null(data$catpred))
       for(j in 1:length(data$catpred))
       {d<-rep(0,nrow(data$dirx))
       p=1
       for(l in data$catpred[[j]])
       {d[data$dirx[,l]==1]<-p
       p=p+1}
       par(mfrow=c(p,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
       overlapHist(a=data$x[,grep(vari,names(data$x))],b=as.matrix(d),xlim=xlim,xname="Predictor",data$w)
       }        
  }
  else{par(mfrow=c(1,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
    if (!x$model$Survival[m])
      plot(full.model$fitted.values~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
    else
      plot(predict(full.model,type=x$model$type)~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
    temp1<-NULL
    if(is.null(data$w)){ #
      if(!is.null(data$binpred)){
        par(mfrow=c(length(data$binpred),2),mar=c(5,5,1,1),oma=c(3,2,5,4))
        for(j in data$binpred){
          temp1<-        prop.table(table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))]))
          temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])))
          barplot(prop.table(table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                  ylab="Prop",sub=paste(colnames(data$dirx)[j], "at the reference level",sep=" "))
          barplot(prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                  ylab="Prop",sub=colnames(data$dirx)[j])}}
      
      if(!is.null(data$catpred)){
        par(mfrow=c(1+nx,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        for(z.c in 1:length(data$catpred)){
          temp1<-prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))]))
          for (j in data$catpred[[z.c]])
            temp1<-c(temp1,prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])))
          barplot(prop.table(table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                  ylab="Prop",sub=paste("Categorical Predictor",z.c, "at the reference level",sep=" "))
          for (j in data$catpred[[z.c]])
            barplot(prop.table(table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))])),ylim=c(0,max(temp1,na.rm=T)),
                    ylab="Prop",sub=colnames(data$dirx)[j])
        }
      }
    }#
    else#
    {if(!is.null(data$binpred)){
      par(mfrow=c(length(data$binpred),2),mar=c(5,5,1,1),oma=c(3,2,5,4))
      for(j in data$binpred){
        temp1<-        weighted.prop.table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))],
                                           data$w[apply(data$dirx,1,sum)==0])
        temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                           data$w[data$dirx[,j]==1]))#
        barplot(weighted.prop.table(data$x[data$dirx[,j]==0,grep(vari,names(data$x))],
                                    data$w[apply(data$dirx!=0,1,sum)==0]),ylim=c(0,max(temp1)),#
                ylab="Prop",sub=paste(colnames(data$dirx)[j],"at the reference level",sep=" ")) #
        barplot(weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                    data$w[data$dirx[,j]==1]),ylim=c(0,max(temp1)),#
                ylab="Prop",sub=colnames(data$dirx)[j])}          
    }
      if(!is.null(data$catpred)){
        par(mfrow=c(1+nx,1),mar=c(5,5,1,1),oma=c(3,2,5,4))
        for(z.c in 1:length(data$catpred)){
          temp1<-weighted.prop.table(data$x[data$dirx[,data$catpred[[z.c]]]==0,grep(vari,names(data$x))],
                                     data$w[apply(data$dirx,1,sum)==0])
          for (j in data$catpred[[z.c]])#
            temp1<-c(temp1,weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],
                                               data$w[data$dirx[,j]==1]))#
          barplot(weighted.prop.table(data$x[apply(data$dirx[,data$catpred[[z.c]]]!=0,1,sum)==0,
                                             grep(vari,names(data$x))],data$w[apply(data$dirx!=0,1,sum)==0]),ylim=c(0,max(temp1)),#
                  ylab="Prop",sub="Predictor at the reference level") #
          for (j in data$catpred[[z.c]])#
            barplot(weighted.prop.table(data$x[data$dirx[,j]==1,grep(vari,names(data$x))],data$w[data$dirx[,j]==1]),ylim=c(0,max(temp1)),#
                    ylab="Prop",sub=colnames(data$dirx)[j])}} 
      } 
  }
}
else
{par(mfrow=c(3,nx),mar=c(5,5,1,1),oma=c(3,2,5,4))
  for (l in data$contpred) {     
    temp2<-data$dirx[,l]
    temp3<-as.matrix(x$ie[[l]][,grep(mname,colnames(x$ie[[l]]))])
    temp3<-temp3[,m]
    temp.order=order(temp2)
    #browser()
    plot(temp2[temp.order], temp3[temp.order],type="l",
         xlab=names(data$dirx)[l],ylab=paste(c("IE of", vari, "on", colnames(data$y)[m]),sep=""))}
  if(!is.factor(data$x[,grep(vari,names(data$x))]))
  {if(!x$model$Survival[m])
    b<-marg.den(data1,full.model$family$linkfun(full.model$fitted.values),data$w) #added data$w
   else
    b<-marg.den(data1,predict(full.model,type=x$model$type),data$w) #added data$w
   plot(b,xlab=mname,ylab=paste("f(",mname,")",sep=""),xlim=xlim)
   abline(a=mean(b[,2],na.rm=T)-coef*mean(b[,1],na.rm=T),b=coef)
   axis(1,at=data1,labels=F)
   if(nx>1)
     for (i in 1:(nx-1))
       plot(1, type="n", axes=F, xlab="", ylab="")
   for(l in 1:data$contpred){
     a<-marg.den(data$x[,l],data$x[,grep(vari,names(data$x))],data$w) #added data$w
     scatter.smooth(a[,1],a[,2],family="gaussian", xlab=colnames(data$dirx)[l],ylim=xlim,ylab=paste("Mean",mname,sep="."))}
  }  
  else
  {if (!x$model$Survival[m])
    plot(full.model$fitted.values~data1,ylab=paste("f(",mname,")",sep=""),xlab=mname)
    else  
      plot(predict(full.model,type=x$model$type)~data$x[-full.model$na.action,grep(vari,names(data$x))],ylab=paste("f(",mname,")",sep=""),xlab=mname)
    if(nx>1)
      for (i in 1:(nx-1))
        plot(1, type="n", axes=F, xlab="", ylab="")
    for(l in data$contpred){
      plot(data$x[,grep(vari,names(data$x))],data$dirx[,l],ylab=colnames(data$dirx)[l],xlab="")}}
  }
}
par(op)
}

if(!is.null(x$a.binx))
  plot2(x=x$a.binx,vari=vari,xlim=xlim,type=1)
if(!is.null(x$a.contx))
  plot2(x=x$a.contx,vari=vari,xlim=xlim,type=2)

}

################################################################################################
# the functions to make inferences on mediation effects using parallel calculation
boot.med.par<-function(data,x=data$x, y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,catm=data$catm,
                       jointm=data$jointm, cova=data$cova,margin=1,n=20,nonlinear=F,df1=1,nu=0.001,
                       D=3,distn=NULL,family1=data$family1,n2=50,w=rep(1,nrow(x)),refy=NULL,x.new=x,
                       pred.new=dirx, cova.new=NULL,binpred=data$binpred,type=NULL,w.new=NULL,ncore=NULL,xmod=NULL,custom.function=NULL)
{boot.med.binx<-function(data,x=data$x, y=data$y,dirx=data$dirx,contm=data$contm,catm=data$catm,
                         jointm=data$jointm, cova=data$cova,n=20,n2=50,nonlinear=F,nu=0.001,
                         D=3,distn="bernoulli",family1=binomial("logit"),
                         w=rep(1,nrow(x)),biny=(data$y_type==2),refy=rep(NA,ncol(y)),
                         surv=(data$y_type==4),type,ncore=NULL,xmod,custom.function=NULL)
  #n2 is the time of bootstrap
{
  med.binx<-function(data, x=data$x, y=data$y, dirx=data$dirx, contm = data$contm, 
                     catm = data$catm, jointm = data$jointm, cova=data$cova, allm = c(contm, catm), 
                     n=20,nonlinear=F,nu=0.001,
                     D=3,distn=NULL,family1=data$family1, #
                     biny=rep(F,ncol(y)),refy=rep(0,ncol(y)),surv=rep(F,ncol(y)),type=NULL,
                     w=NULL,xmod=NULL,custom.function=NULL) #
  {if (is.null(allm))
    stop("Error: no potential mediator is specified")
    xnames<-colnames(x)
    pred_names<-colnames(dirx)  #
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else
      cova_names=colnames(cova[[1]])}
    
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(catm))
      catm<-unlist(sapply(catm,grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    allm=c(contm,catm)
    
    te.binx<-function(full.model,new1,new0,best.iter1=NULL,surv,type)       
    {te<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
      else if (surv[m])
        te[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      te
    }
    
    med.binx.contm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    marg.m<-c(nom1[,med],nom0[,med])[sample(1:n3,replace=T)]
    new1<-nom1
    new1[,med]<-marg.m[1:nrow(nom1)]
    new0<-nom0
    new0[,med]<-marg.m[(nrow(nom1)+1):n3]
    if(!is.null(xmod))
    {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
    if(sum(temp.x)>0)
    {m.t=1
    m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
    m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
    for (m.t1 in temp.x)
    {new0[,m.t1]=m.t2[,m.t]
    new1[,m.t1]=m.t3[,m.t]
    m.t=m.t+1}}
    }
    dir.nom<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
    else if(surv[m])
      dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    dir.nom
    }
    
    med.binx.jointm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,temp.rand,xmod,xnames)  
    {if (length(med)==1)                       #added for the new program, when there is only one mediator
    {if(is.factor(nom1[,med]))              #added to control for one factor mediator
      marg.m<-as.factor(c(as.character(nom1[,med]),as.character(nom0[,med]))[temp.rand])
    else
      marg.m<-c(nom1[,med],nom0[,med])[temp.rand]
    }        
      else                                         #added for the new program
        marg.m<-rbind(nom1[,med],nom0[,med])[temp.rand,]
      new1<-nom1
      new0<-nom0
      if(length(med)==1)                                       #added for the new program, when there is only one mediator
      {new1[,med]<-marg.m[1:nrow(new1)]                     #added for the new program 
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0))]}  #added for the new program
      else                                                     #added for the new program
      {new1[,med]<-marg.m[1:nrow(new1),]
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0)),]}
      if(!is.null(xmod))
        for (z in med)
        {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
        m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0[,m.t1]=m.t2[,m.t]
        new1[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
      dir.nom<-NULL
      for (m in 1:length(full.model))
        if(surv[m] & !is.null(best.iter1[m]))
          dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
      else if(surv[m])
        dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      dir.nom
    }
    
    med.binx.catm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    temp.rand<-unlist(list(nom1[,med],nom0[,med]))[sample(1:n3,replace=T)]
    marg.m1<-temp.rand[1:nrow(nom1)]
    marg.m2<-temp.rand[(nrow(nom1)+1):n3]
    dir.nom<-rep(0,length(full.model))
    for (m in 1:length(full.model))
      for (i in levels(x[,med]))
      {new1<-nom1
      new1[1:dim(new1)[1],med]<-i
      new0<-nom0
      new0[1:dim(new0)[1],med]<-i
      if(!is.null(xmod))
      {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
      m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
      for (m.t1 in temp.x)
      {new0[,m.t1]=m.t2[,m.t]
      new1[,m.t1]=m.t3[,m.t]
      m.t=m.t+1}}
      }
      p<-mean(temp.rand==i,na.rm=T)
      if(surv[m] & !is.null(best.iter1[m]))
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T))
      else if(surv[m])
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T))
      else
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T))
      }
    dir.nom
    }
    
    #1.fit the model
    x2<-cbind(x,dirx)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    
    for (j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      x1<-x2[!is.na(y[,j]),]             #delete nas in y for mart
      y1<-y[!is.na(y[,j]),j]
      w1<-w[!is.na(y[,j])]
      if(!is.null(custom.function)){
        if(!is.na(custom.function[j])){
          cf1=gsub("responseY","y1",custom.function[j])
          cf1=gsub("dataset123","x1",cf1)
          cf1=gsub("weights123","w1",cf1)
          full.model[[j]]<-eval(parse(text=cf1))
        }
        else if (nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                   distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
        else
          full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
        }
      }
      else if (nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                 distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
      else
        full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    te<-matrix(0,n,ncol(y)*ncol(dirx))
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
    if(!is.null(jointm))
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))+jointm[[1]]))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")
    }
    else
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".")
    }
    denm<-rep(list(denm),ncol(dirx))
    ie<-denm
    #3. repeat to get the mediation effect
    for (k in 1:n)
    {#3.1 get the te         full.model,x,y,dirx,best.iter1=NULL
      x0.temp<-apply(dirx==1,1,sum)==0  #indicator of the reference group
      x0<-x2[x0.temp,]
      if(is.null(w))
      {w1<-NULL
      w0<-NULL}
      else
        w0<-w[x0.temp]
      for (l in 1:ncol(dirx))  #l indicate the lth predictor
      {x1.2<-x2[dirx[,l]==1,]
      if(!is.null(w))
        w1<-w[dirx[,l]==1]
      #n3<-dim(x)[1] use the original size
      new1<-x1.2[sample(1:nrow(x1.2),replace=T,prob=w1),] #floor(n3/2),
      new0<-x0[sample(1:nrow(x0),replace=T,prob=w0),] #floor(n3/2),
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-te.binx(full.model,new1,new0,best.iter1,surv,type)  
      temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
      #the indirect effect of all mediators
      temp.ie<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-med.binx.jointm(full.model,new1,new0,allm,best.iter1,surv,type,temp.rand,xmod,xnames) #add temp.rand
      #new method to calculate the direct effect     
       x.temp=data.frame(x[dirx[,l]==1 | x0.temp,])
      new1.temp=data.frame(x.temp[temp.rand[1:nrow(x1.2)],],dirx[dirx[,l]==1,])
      new0.temp=data.frame(x.temp[temp.rand[(nrow(x1.2)+1):(nrow(x1.2)+nrow(x0))],],dirx[x0.temp,])
      colnames(new1.temp)<-c(xnames,pred_names)
      colnames(new0.temp)<-c(xnames,pred_names)
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0.temp,dirx[x0.temp,],inter.cov=xmod)
        m.t3=form.interaction(new1.temp,dirx[dirx[,l]==1,],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0.temp[,m.t1]=m.t2[,m.t]
        new1.temp[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}}
      denm[[l]][k,1:ncol(y)]<-te.binx(full.model,new1.temp,new0.temp,best.iter1,surv,type) #add temp.rand
      
      j<-2
      #3.2 mediation effect from the continuous mediator
      if (!is.null(contm))
        for (i in contm)          #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.contm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.3.mediation effect from the categorical mediator
      if (!is.null(catm))
        for (i in catm)           #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.catm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.4 mediation effect from the joint mediators
      if (!is.null(jointm))
        for (i in 1:jointm[[1]])          #full.model,x,y,med,dirx,best.iter1=NULL
        {temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
        denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.jointm(full.model,new1,new0,jointm[[i+1]],best.iter1,surv,type,temp.rand,xmod,xnames)
        j<-j+1}
      #3.5 get the indirect effects and total effect
      ie[[l]][k,]<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-denm[[l]][k,]
      ie[[l]][k,1:ncol(y)]<-temp.ie
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-denm[[l]][k,1:ncol(y)]+temp.ie
      
      if(!is.null(jointm))
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")#c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep=""))
      else
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".") #c("all",colnames(x)[c(contm,catm)])
      }
    }
    names(denm)<-pred_names
    names(ie)<-pred_names
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear, Survival=surv, type=type, model=full.model,best.iter=best.iter1),data=data)
    class(a)<-"med"
    return(a)
  }
  
  if (is.null(c(contm,catm)))
    stop("Error: no potential mediator is specified")
  
  #set.seed(seed)
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  ynames=colnames(y)
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
    cova_names=colnames(cova)
    else 
    cova_names=colnames(cova[[1]])}
  
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(catm))
    catm<-unlist(sapply(catm,grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  allm=c(contm,catm)
  ny=ncol(y)
  nx=ncol(dirx)
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  if(is.null(jointm))
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))))
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  else 
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie1)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names
  temp<-med.binx(data=NULL,x,y,dirx,contm,catm,jointm,cova,allm,n,nonlinear,nu,D,distn,family1,biny,refy,surv,type,w=w,xmod,custom.function)
  te[1,]<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie1[l,]<-apply(temp$ie[[l]],2,mean)}  #first row is the estimated value
  de[1,]<-apply(temp.1,2,mean,na.rm=T)
  model<-temp$model
  best.iter<-temp$best.iter
  
  registerDoParallel(cores=ncore)
  r<-foreach(i=1:n2,.combine=rbind,.packages =c('gbm','survival','splines','doParallel'))  %dopar% 
  {boots<-sample(1:nrow(x),replace=T,prob=w)
  x1<-data.frame(x[boots,])
  names(x1)=xnames
  y1<-data.frame(y[boots,])
  colnames(y1)=ynames
  pred1<-data.frame(dirx[boots,])
  colnames(pred1)=pred_names
  temp<-med.binx(data=NULL,x=x1, y=y1, dirx=pred1, contm=contm, catm=catm,jointm=jointm,cova=cova,allm=allm,n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,biny=biny,refy=refy,surv=surv,type=type,w=NULL,xmod,custom.function)
  te1<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  ie1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie1<-c(ie1,apply(temp$ie[[l]],2,mean,na.rm=T))}  #first row is the estimated value
  de1<-apply(temp.1,2,mean,na.rm=T)
  c(te1,de1,ie1)  
  }
  
  nxy=ny*nx
  nie=ncol(ie1)
  te[2:(n2+1),]<-r[,1:nxy]
  de[2:(n2+1),]<-r[,(nxy+1):(2*nxy)]
  temp.col<-2*nxy
  for (l in 1:nx)
  {ie[[l]][1:n2,]<-r[,(temp.col+1):(temp.col+nie)]
  temp.col<-temp.col+nie}
  
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model, 
          data=list(x=x,y=y,dirx=dirx,contm=contm,catm=catm,jointm=jointm,cova=cova, binpred=T),mod=F)
  class(a)<-"mma"
  return(a)
}

boot.med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,
                         catm=data$catm, jointm=data$jointm,cova=data$cova, margin=1, n=20,
                         nonlinear=F,df1=1,nu=0.001,D=3,distn="gaussian",
                         family1=gaussian(link="identity"),n2=50,
                         w=rep(1,nrow(x)),biny=(data$y_type==2),refy=rep(NA,ncol(y)),
                         x.new=x,pred.new=dirx,cova.new=cova,surv,type,w.new=NULL,ncore=NULL,xmod=NULL,custom.function=NULL)
{
  med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,
                      catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                      nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=data$family1,
                      biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx, cova.new=cova, surv=(data$y_type==4),
                      type=NULL,w=NULL, w.new=NULL, xmod=NULL,custom.function=NULL)
  {if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
    # browser()
    xnames<-colnames(x)
    pred_names<-colnames(dirx)
    ynames<-colnames(y)
    if(!is.null(cova)) {
      if(length(grep("for.m",names(cova)))==0)
        cova_names=colnames(cova)
      else 
        cova_names=colnames(cova[[1]])}
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(binm))
      binm<-unlist(sapply(binm,grep,xnames))
    if(!is.null(catm))
      for (i in 2:length(catm))
        if(is.character(catm[[i]]))
          catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    anymissing<-function(vec) #return T if there is any missing in the vec
    {if(sum(is.na(vec))>0)
      return(F)
      else return(T)
    }
    
    col_mean<-function(col,n.row,w=NULL)
    {temp<-matrix(col,n.row)
    if(is.null(w))
      return(apply(temp,1,mean,na.rm=T))
    else
      return(apply(temp,1,weighted.mean,na.rm=T,w=w))}
    
    
    dist.m.given.x<-function(x,dirx,binm=NULL,contm=NULL,catm=NULL,nonlinear,df1,w,cova) #give the model and residual of m given x
    {
      getform=function(z,nonlinear,df1)
      {if(!nonlinear)
        formu="x[,i]~."
      else
      {names.z=colnames(z)
      temp.t=unlist(lapply(z,is.character)) | unlist(lapply(z,is.factor))
      names.z1=names.z[!temp.t]
      names.z2=names.z[temp.t]
      if(length(names.z1)==0)
        formu="x[,i]~."
      else if (length(names.z2)==0)
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),sep="")
      else
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),"+",
                    paste(names.z2,collapse="+"),sep="")
      }
      formu
      }
      #browser()  
      models<-NULL
      x=data.frame(x)
      res<-NULL
      temp.namec=colnames(x)
      indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
      if(!is.null(cova))
        if(length(grep("for.m",names(cova)))!=0)
          for (i in 1:length(cova[[2]]))
            indi=c(indi,grep(cova[[2]][i],temp.namec))
      if(!is.null(catm))
      {for (i in 2:(catm$n+1))
        binm<-c(binm,catm[[i]])}
      
      z<-dirx
      z.name=paste("predictor",1:ncol(z),sep=".")
      colnames(z)=z.name
      # browser()
      if(!is.null(cova))
      {if (length(grep("for.m",names(cova)))==0)#create the predictor matrix z
        z<-cbind(z,cova)
      else 
      {
        z1<-cbind(z,cova[[1]])
        form1=getform(z1,nonlinear,df1)
      }}
      
      form0=getform(z,nonlinear,df1)
      j<-1
      
      if(!is.null(binm))
      {for(i in binm)
      {if(!i%in%indi)
      {models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=binomial(link = "logit"),weights=w)
      res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z=z)))}
        else
        {models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=binomial(link = "logit"),weights=w)
        res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z=z1)))}
        j<-j+1}
      }
      # browser()
      for (i in contm)
      {if(!i%in%indi)
        models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=gaussian(link="identity"),weights=w)
      else
        models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=gaussian(link="identity"),weights=w)
      res<-cbind(res,models[[j]]$res)
      j<-j+1
      }
      list(models=models,varmat=var(res))
    }
    
    
    sim.xm<-function(distmgivenx,x1,dirx,binm,contm,catm,nonlinear,df1,cova)  #added nonlinear and df1 to sim.xm
    {mult.norm<-function(mu,vari,n) 
    {if (nrow(vari)!=ncol(vari)) 
      result<-c("Error: Variance matrix is not square")  
    else if (length(mu)!=nrow(vari)) 
      result<-c("Error: length mu is not right!")  
    else {   p<-length(mu)
    tmp1<-eigen(vari)$values
    tmp2<-eigen(vari)$vectors   
    result<-matrix(0,n,p)   
    for (i in 1:p)
    {result[,i]<-rnorm(n,mean=0,sd=sqrt(tmp1[i]))}   
    for (i in 1:n)
    {result[i,]<-tmp2%*%result[i,]+mu}
    }  
    result
    }
    
    match.margin<-function(vec)   
    {range1<-vec[1:2]
    vec1<-vec[-(1:2)]
    range2<-range(vec1,na.rm=T)
    vec1<-range1[1]+diff(range1)/diff(range2)*(vec1-range2[1])
    vec1
    }
    
    gen.mult<-function(vec)
    {if(sum(is.na(vec))>0)
      return(rep(NA,length(vec)))
      else{ 
        l<-1-sum(vec)
        l<-ifelse(l<0,0,l)
        return(rmultinom(1,size=1,prob=c(l,vec))[-1])}
    }
    
    x1=data.frame(x1)
    temp.namec=colnames(x1)
    indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
    if(!is.null(cova))
      if(length(grep("for.m",names(cova)))!=0)
        for (i in 1:length(cova[[2]]))
          indi=c(indi,grep(cova[[2]][i],temp.namec))
    
    means<-NULL
    z<-dirx
    z.name=paste("predictor",1:ncol(z),sep=".")
    colnames(z)=z.name
    
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)   #create the predictor matrix z
      z<-cbind(z,cova)
    else 
      z1<-cbind(z,cova[[1]])}
    
    binm1<-binm
    
    if(!is.null(catm))
    {for (i in 2:(catm$n+1))
      binm1<-c(binm1,catm[[i]])}
    if(!is.null(binm1))
      for (i in 1:length(binm1))
      {if(binm1[i]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z1)))
      else  
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z)))}
    if(!is.null(contm))
      for (i in (length(binm1)+1):length(c(binm1,contm)))
      {if(contm[i-length(binm1)]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z1)))
      else
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z)))}
    
    if(dim(means)[2]==1)                                                   #added in the new program, in case there is only one mediator
    {sim.m<-suppressWarnings(rnorm(length(means),mean=means,sd=sqrt(distmgivenx$varmat)))     #added in the new program
    sim.m2<-match.margin(c(range(means,na.rm=T),sim.m))}                          #added in the new program   
    else{
      sim.m<-t(apply(means,1,mult.norm,vari=distmgivenx$varmat,n=1))
      
      range.means<-apply(means,2,range,na.rm=T)
      
      sim.m2<-apply(rbind(range.means,sim.m),2,match.margin)    #to make the simulate fit the means' ranges
    }
    sim.m2<-data.frame(sim.m2)
    n<-dim(sim.m2)[1]
    if(!is.null(binm))
      for (i in 1:length(binm))
        sim.m2[,i]<-rbinom(n,size=1,prob=sim.m2[,i])
    
    if(!is.null(catm))
    {j<-length(binm)+1
    for (i in 2:(catm$n+1))
    {a<-sim.m2[,j:(j+length(catm[[i]])-1)]
    sim.m2[,j:(j+length(catm[[i]])-1)]<-t(apply(a,1,gen.mult))
    j<-j+length(catm[[i]])}
    }
    
    x1[,c(binm1,contm)]<-sim.m2
    
    x1
    }
    
    if(is.null(catm))
      multi=jointm
    else if(is.null(jointm))
      multi=catm
    else {temp1<-catm
    temp2<-jointm
    temp1[[1]]=catm[[1]]+jointm[[1]]
    temp2[[1]]<-NULL
    multi=append(temp1,temp2)} 
    listm=list(single=c(contm,binm),multi=multi)
    
    if (is.null(multi))                      #allm list all mediators
    {tempm<-multi
    tempm[[1]]<-NULL}
    else  tempm<-NULL
    allm<-unique(c(contm,binm,unlist(tempm)))
    nonmissing<-apply(cbind(y,x[,listm$single],dirx),1,anymissing)
    temp.name1=colnames(x)
    x<-data.frame(x[nonmissing,])
    colnames(x)=temp.name1
    y<-data.frame(y[nonmissing,])
    if(!is.null(cova))
    {cova=data.frame(cova[nonmissing,])
    colnames(cova)=cova_names}
    colnames(y)<-ynames
    pred<-data.frame(dirx[nonmissing,])
    colnames(pred)<-pred_names
    w<-w[nonmissing]
    nonmissing1<-apply(cbind(x.new[,listm$single],pred.new),1,anymissing)
    temp.name1=colnames(x.new)
    x.new<-data.frame(x.new[nonmissing1,])
    colnames(x.new)=temp.name1
    w.new<-w.new[nonmissing1]
    pred.new<-data.frame(pred.new[nonmissing1,])
    colnames(pred.new)<-pred_names
    if(!is.null(cova.new))  
    {cova.new=data.frame(cova.new[nonmissing,])
    colnames(cova.new)=cova_names}
    
    #1.fit the model
    x2<-cbind(x,pred)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    for(j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      
      if(!is.null(custom.function))
      { if(!is.na(custom.function[j]))
      {cf1=gsub("responseY","y[,j]",custom.function[j])
      cf1=gsub("dataset123","x2",cf1)
      cf1=gsub("weights123","w",cf1)
      full.model[[j]]<-eval(parse(text=cf1))}
        else if(nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                   distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
        }
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
        else
          full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
        }
      }
      else if(nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                 distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
      }
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
      else
        full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    n.new<-nrow(x.new)
    
    #3. get the joint distribution of m given x
    distmgivenx<-dist.m.given.x(x,pred,binm,contm,catm,nonlinear,df1,w,cova)
    te1.0<-NULL
    denm1.0<-NULL
    denm1.1<-NULL
    n1<-dim(x)[1]
    
    #4. repeat to get the mediation effect
    for (l in 1:ncol(pred)) {
      denm1<-NULL
      denm1.2=NULL
      te1<-NULL
      for (k in 1:n)
      {new0<-sim.xm(distmgivenx,x.new,pred.new,binm,contm,catm,nonlinear,df1,cova.new) #draw ms conditional on x.new
      temp.pred<-pred.new
      temp.pred[,l]<-temp.pred[,l]+margin
      if(!is.null(xmod))   #allows the interaction of pred with xmod
      {cova.new1=cova.new
      x.new1=x.new
      if(!is.null(cova.new))
      {temp.cova=intersect(grep(pred_names[l],cova_names),grep(xmod,cova_names))
      if(sum(temp.cova)>0)
      {m.t=1
      m.t2=form.interaction(cova.new,temp.pred[,l],inter.cov=xmod)
      for (m.t1 in temp.cova)
      {cova.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}
      }}
      temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(x.new,temp.pred[,l],inter.cov=xmod)
      for (m.t1 in temp.x)
      {x.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}}
      new1<-sim.xm(distmgivenx,x.new1,temp.pred,binm,contm,catm,nonlinear,df1,cova.new1)  #draw from the conditional distribution of m given x
      }
      else
        new1<-sim.xm(distmgivenx,x.new,temp.pred,binm,contm,catm,nonlinear,df1,cova.new)  #draw from the conditional distribution of m given x
      new1<-cbind(new1,temp.pred)   #draw ms conditional on x.new+margin
      new0<-cbind(new0,pred.new) 
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      denm2<-NULL
      
      #browser()   
      
      sample.temp<-sample(1:n.new,2*n.new,replace = T,prob=w.new)   #random sample from the original data
      
      #4.0.0 get the total indirect effect
      temp.new1<-new1
      temp.new1[,allm]<-x.new[sample.temp[1:n.new],allm]
      temp.new0<-new0
      temp.new0[,allm]<-x.new[sample.temp[(n.new+1):(2*n.new)],allm]
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(x.new[sample.temp[1:n.new],],x.new[sample.temp[1:n.new],z],inter.cov=xmod)
          m.t3=form.interaction(x.new[sample.temp[(n.new+1):(2*n.new)],],x.new[sample.temp[(n.new+1):(2*n.new)],z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {temp.new1[,m.t1]=m.t2[,m.t]
          temp.new0[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin
      else if(surv[m])
        denm3<-(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin
      else
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin
      
      #4.0 get the direct effect
      temp.new1<-x.new[sample.temp[1:n.new],]
      temp.new1=cbind(temp.new1,temp.pred)
      temp.new0<-x.new[sample.temp[(n.new+1):(2*n.new)],]
      temp.new0=cbind(temp.new0,pred.new)
      colnames(temp.new1)<-c(xnames,pred_names)
      colnames(temp.new0)<-c(xnames,pred_names)
      
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(temp.new1,temp.pred[,l],inter.cov=xmod)
        m.t3=form.interaction(temp.new0,pred.new[,l],inter.cov=xmod)
        for (m.t1 in temp.x)
        {temp.new1[,m.t1]=m.t2[,m.t]
        temp.new0[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
      }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin)
      else
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin)
      
      #4.1 get the te
      te0<-NULL
      for(m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m],type=type)-predict(full.model[[m]],new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        te0<-c(te0, (predict(full.model[[m]],new1,type=type)-predict(full.model[[m]],new0,type=type))/margin)
      else
        te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m])-predict(full.model[[m]],new0,best.iter1[m]))/margin)
      te1<-cbind(te1,te0)
      
      #4.2 mediation effect from the single mediator
      # browser()
      if (!is.null(listm$single))
        for (i in 1:length(listm$single))
        {new1.nm<-new1
        new0.nm<-new0
        temp.m<-x.new[sample.temp,listm$single[i]]
        new1.nm[,listm$single[i]]<-temp.m[1:n.new]    #draw m from its original distribution
        new0.nm[,listm$single[i]]<-temp.m[(n.new+1):(2*n.new)]    #draw m from its original distribution
        
        if(!is.null(xmod))
        {temp.x=intersect(grep(xnames[listm$single[i]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new1.nm,new1.nm[,listm$single[i]],inter.cov=xmod)
        m.t3=form.interaction(new0.nm,new0.nm[,listm$single[i]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new1.nm[,m.t1]=m.t2[,m.t]
        new0.nm[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      
      #4.3.mediation effect from the joint mediator
      if (!is.null(listm$multi))
        for (i in 2:(listm$multi[[1]]+1))
        {new1.nm<-new1
        new0.nm<-new0
        new1.nm[,listm$multi[[i]]]<-x.new[sample.temp[1:n.new],listm$multi[[i]]]    #draw m from its original distribution
        new0.nm[,listm$multi[[i]]]<-x.new[sample.temp[(n.new+1):(2*n.new)],listm$multi[[i]]]    #draw m from its original distribution
        
        if(!is.null(xmod))
          for (z in listm$multi[[i]])
          {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new1.nm,new1.nm[,z],inter.cov=xmod)
          m.t3=form.interaction(new0.nm,new0.nm[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new1.nm[,m.t1]=m.t2[,m.t]
          new0.nm[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
          }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      denm1<-rbind(denm1,denm2)
      denm1.2=rbind(denm1.2,as.matrix(denm3))
      }
      denm1.0[[l]]<-denm1 
      denm1.1[[l]]<-denm1.2 
      te1.0[[l]]<-te1
    } 
    
    #4.4 get the indirect effects
    denm<-NULL
    denm1<-NULL
    te<-NULL
    ie<-NULL
    for (l in 1:ncol(pred))
    {denm[[l]]<-apply(denm1.0[[l]],2,col_mean,n.new)
    denm1[[l]]<-apply(denm1.1[[l]],2,col_mean,n.new)
    te0<-matrix(apply(te1.0[[l]],1,mean),n.new)
    #te<-cbind(te,te0)
    temp1<-ncol(denm[[l]])/ncol(te0)
    temp2<-NULL
    for(temp in 1:temp1)
      temp2<-cbind(temp2,te0)
    ie[[l]]<-temp2-denm[[l]]
    ie[[l]][,1:ncol(y)]=matrix(rep(te0,ncol(y)),ncol=ncol(y))-denm1[[l]]      #the total indirect effect
    te=cbind(te,ie[[l]][,1:ncol(y)]+denm[[l]][,1:ncol(y)])                    #the total effect
    if(!is.null(listm$multi)) 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    if(!is.null(listm$multi))
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    }
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
    names(denm)<-pred_names
    names(ie)<-pred_names
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear,Survival=surv, type=type, model=full.model,best.iter=best.iter1),pred.new=pred.new,w.new=w.new,data=data,distmgivenx=distmgivenx)
    class(a)<-"med"
    return(a)
  }
  
  anymissing<-function(vec)
  {if(sum(is.na(vec))>0)
    return(F)
    else return(T)
  }
  
  col_mean1<-function(col,n.row,w=NULL)
  {temp<-matrix(col,n.row)
  if(is.null(w))
    return(apply(temp,2,mean,na.rm=T))
  else
    return(apply(temp,2,weighted.mean,na.rm=T,w=w))}
  
  stock<-function(mat,rows)
  {if(nrow(mat)==rows)
    temp=mat
  else{
    temp<-mat[1:rows,]
    temp1=rows
    while(temp1<nrow(mat))   
    {temp<-cbind(temp,mat[(temp1+1):(temp1+rows),])
      temp1<-temp1+rows}
  }
  temp
  }
  
  if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
  
 # set.seed(seed)
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
    cova_names=colnames(cova)
  else 
    cova_names=colnames(cova[[1]])}
  ynames=colnames(y)
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(binm))
    binm<-unlist(sapply(binm,grep,xnames))
  if(!is.null(catm))
    for (i in 2:length(catm))
      if(is.character(catm[[i]]))
        catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  if(is.null(catm))
  {multi=jointm
  name1<-NULL                       #added in the new program
  if (!is.null(multi))              #added in the new program, in case that multi is NULL
    name1<-paste("j",1:multi[[1]],sep="")}
  else if(is.null(jointm))
  {multi=catm
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])}
  else {temp1<-catm
  temp2<-jointm
  temp1[[1]]=catm[[1]]+jointm[[1]]
  temp2[[1]]<-NULL
  multi=append(temp1,temp2)
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])
  name1<-c(name1,paste("j",1:jointm[[1]],sep=""))} 
  listm=list(single=c(contm,binm),multi=multi)
  
  ny=ncol(y)
  nx=ncol(dirx)
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  mul<-ifelse(is.null(multi),0,multi[[1]])        #added in the new program, in case multi is null
  ie<-matrix(0,n2,ny*(1+length(listm$single)+mul))   #added in the new program
  ie1<-matrix(0,nx,ny*(1+length(listm$single)+mul))   #added in the new program
  if(!is.null(listm$multi))
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  else 
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names
  
  temp.med<-med.contx(data=NULL,x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova, 
                  margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,distn=distn,family1=family1,biny=biny,
                  refy=refy,x.new=x.new,pred.new=pred.new,cova.new=cova.new, surv,type,w=w,w.new=w.new,xmod=xmod,custom.function=custom.function)
  temp=temp.med
  temp.1<-NULL
  for (l in 1:nx)
    temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  if(is.null(w.new))
  {te[1,]<-apply(temp$te,2,mean,na.rm=T)
  de[1,]<-apply(temp.1,2,mean,na.rm=T) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
  }
  else
  {te[1,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
  de[1,]<-apply(temp$denm[,1],2,weighted.mean,na.rm=T,w=w.new) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T,w=w.new)  #first row is the estimated value
  }
  
  te1<-NULL                      #to store the mediation effects on predictor
  de1<-NULL
  ie2<-rep(list(NULL),nx)
  names(ie2)<-pred_names
  model<-temp$model
  
  registerDoParallel(cores=ncore)
  l<-1
  r<-foreach(l=1:n2, .combine=rbind,.packages =c('gbm','survival','splines','doParallel'))  %dopar% 
  {boots<-sample(1:nrow(x),replace=T, prob=w)
  x1<-data.frame(x[boots,])
  colnames(x1)=xnames
  y1<-data.frame(y[boots,])
  colnames(y)=ynames
  dirx1<-data.frame(dirx[boots,])
  colnames(dirx1)=pred_names
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
  {cova1<-data.frame(cova[boots,])
  colnames(cova1)=cova_names}
  else
  {cova1=cova
  cova1[[1]]=data.frame(cova[[1]][boots,])
  colnames(cova1[[1]])=cova_names
  names(cova1[[1]])=names(cova[[1]])}}
  else
    cova1=NULL  
  
  temp<-med.contx(data=NULL,x=x1,y=y1,dirx=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova1, 
                  margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D, distn=distn,
                  family1=family1,biny=biny,refy=refy,x.new=x.new,pred.new=pred.new,cova.new=cova.new,
                  surv=surv,type=type,xmod=xmod,custom.function=custom.function) #added to the new codel, change the seed to make different results
  temp.1<-NULL
  temp.2<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  temp.2<-cbind(temp.2,temp$ie[[l]])}
  te1<-temp$te  #n*nxy
  de1<-temp.1   #n*nxy
  ie1<-temp.2   #n*(nxy*nie)
  cbind(te1,de1,ie1)
  }
  nxy=nx*ny
  te1<-stock(as.matrix(r[,1:nxy]),nrow(x.new))
  de1<-stock(as.matrix(r[,(1+nxy):(2*nxy)]),nrow(x.new))
  nie<-ncol(ie[[1]])
  temp.count<-2*nxy
  for(l in 1:nx)
  {ie2[[l]]<-r[,(temp.count+1):(temp.count+nie)]
  temp.count=temp.count+nie}
  
  if(is.null(w.new))
  {te[2:(n2+1),]<-matrix(apply(te1,2,mean,na.rm=T),ncol=nxy,byrow=T)
  de[2:(n2+1),]<-matrix(apply(de1,2,mean,na.rm=T),ncol=nxy,byrow=T)
  for (l in 1:nx)
    ie[[l]]<-apply(ie2[[l]],2,col_mean1,nrow(x.new))  #first row is the estimated value
  }
  else
  {te[2:(n2+1),]<-matrix(apply(te1,2,weighted.mean,na.rm=T,w=w.new),ncol=nxy,byrow=T)
  de[2:(n2+1),]<-matrix(apply(de1,2,weighted.mean,na.rm=T,w=w.new),ncol=nxy,byrow=T)
  for (l in 1:nx)
    ie[[l]]<-apply(ie2[[l]],2,col_mean1,nrow(x.new),w=w.new)  #first row is the estimated value
  }
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  missing.pred.new<-apply(pred.new,1,anymissing)
  pred.new<-data.frame(pred.new[missing.pred.new,])
  
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model,
          data=list(x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm, jointm=jointm, cova=cova, binpred=F),
          boot.detail=list(pred.new=pred.new,te1=te1,de1=de1,ie1=ie2),w.new=w.new,mod=F,med=temp.med)
  class(a)<-"mma"
  return(a)
}

if(is.null(data)){
  surv=rep(F,ncol(y))
  biny=rep(F,ncol(y))
  if(is.null(distn))
    distn<-rep(NA,ncol(y))
  for(j in 1:ncol(y)) {
    if(class(y[,j])=="Surv"){
      surv[j]=T
      if(is.na(distn[j]))
        distn[j]="coxph"
      if(is.null(type) & nonlinear)
        type="response"
      else if (is.null(type))
        type="risk"
    }
    else if(is.character(y[,j]) | is.factor(y[,j]) | nlevels(as.factor(y[,j]))==2)
    {biny[j]=T
    if(is.na(family1[[j]]))
      family1[[j]] = binomial("logit")
    if(is.na(distn[j]))
      distn[j]="bernoulli" 
    if(!is.na(refy[j]))
      y[,j]<-ifelse(y[,j]==refy[j],0,1)
    else
      y[,j]<-ifelse(as.factor(y[,j])==levels(as.factor(y[,j]))[1],0,1)
    }
    else { 
      if(is.na(family1[[j]]))
        family1[[j]] = gaussian(link = "identity")
      if(is.na(distn[j]))
        distn[j]="gaussian" 
    }
  }
}
else
{biny=data$y_type==2
surv=data$y_type==4
if(sum(surv)>0 & is.null(type) & nonlinear)
  type="response"
else if (sum(surv)>0 & is.null(type))
  type="risk"
if(is.null(distn))
  distn<-rep(NA,ncol(y))
distn[is.na(distn) & data$y_type==2]="bernoulli"
distn[is.na(distn) & data$y_type==4]="coxph"
distn[is.na(distn) & data$y_type==1]="gaussian"
}

if(binpred)
  a<-boot.med.binx(data=data,x=x, y=y,dirx=dirx,contm=contm,catm=catm,
                   jointm=jointm,cova=cova,n=n,n2=n2,nonlinear=nonlinear,nu=nu,
                   D=D,distn=distn,family1=family1,
                   w=w,biny=biny,refy=rep(0,ncol(y)),surv,type,xmod,custom.function)
else
  a<-boot.med.contx(data=data,x=x,y=y,dirx=dirx,binm=binm,contm=contm,
                    catm=catm, jointm=jointm, cova=cova, margin = margin, n = n,  
                    nonlinear = nonlinear, df1 = df1, nu = nu, D = D, distn = distn, 
                    family1 = family1, n2 = n2,w=w,
                    biny=biny,refy=rep(0,ncol(y)),x.new=x.new,pred.new=pred.new,cova.new=cova.new,
                    surv,type,w.new,xmod,custom.function)

return(a)
}


mma.par<-function(x,y,pred,mediator=NULL, contmed=NULL,binmed=NULL,binref=NULL,
                  catmed=NULL,catref=NULL,jointm=NULL,cova=NULL,refy=rep(NA,ncol(data.frame(y))),
                  predref=NULL,alpha=0.1,alpha2=0.1, margin=1, n=20,
                  nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=as.list(rep(NA,ncol(data.frame(y)))),
                  n2=50,w=rep(1,nrow(x)), testtype=1, x.new=NULL, pred.new=NULL, cova.new=NULL, type=NULL,
                  w.new=NULL, ncore=NULL,xmod=NULL,custom.function=NULL)
{boot.med.binx<-function(data,x=data$x, y=data$y,dirx=data$dirx,contm=data$contm,catm=data$catm,
                         jointm=data$jointm, cova=data$cova,n=20,n2=50,nonlinear=F,nu=0.001,
                         D=3,distn="bernoulli",family1=binomial("logit"),
                         w=rep(1,nrow(x)),biny=(data$y_type==2),refy=rep(NA,ncol(y)),
                         surv=(data$y_type==4),type,ncore=NULL,xmod=NULL,custom.function=NULL)
  #n2 is the time of bootstrap
{
  med.binx<-function(data, x=data$x, y=data$y, dirx=data$dirx, contm = data$contm, 
                     catm = data$catm, jointm = data$jointm, cova=data$cova, allm = c(contm, catm), 
                     n=20,nonlinear=F,nu=0.001,
                     D=3,distn=NULL,family1=data$family1, #
                     biny=rep(F,ncol(y)),refy=rep(0,ncol(y)),surv=rep(F,ncol(y)),type=NULL,
                     w=NULL,xmod=NULL,custom.function=NULL) #
  {if (is.null(allm))
    stop("Error: no potential mediator is specified")
    xnames<-colnames(x)
    pred_names<-colnames(dirx)  #
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)
      cova_names=colnames(cova)
    else
      cova_names=colnames(cova[[1]])}
    
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(catm))
      catm<-unlist(sapply(catm,grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    allm=c(contm,catm)
    
    te.binx<-function(full.model,new1,new0,best.iter1=NULL,surv,type)       
    {te<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
      else if (surv[m])
        te[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        te[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      te
    }
    
    med.binx.contm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    marg.m<-c(nom1[,med],nom0[,med])[sample(1:n3,replace=T)]
    new1<-nom1
    new1[,med]<-marg.m[1:nrow(nom1)]
    new0<-nom0
    new0[,med]<-marg.m[(nrow(nom1)+1):n3]
    if(!is.null(xmod))
    {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
    if(sum(temp.x)>0)
    {m.t=1
    m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
    m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
    for (m.t1 in temp.x)
    {new0[,m.t1]=m.t2[,m.t]
    new1[,m.t1]=m.t3[,m.t]
    m.t=m.t+1}}
    }
    dir.nom<-NULL
    for(m in 1:length(full.model))
      if(surv[m] & !is.null(best.iter1[m]))
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
    else if(surv[m])
      dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
    else
      dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
    dir.nom
    }
    
    med.binx.jointm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,temp.rand,xmod,xnames)  
    {if (length(med)==1)                       #added for the new program, when there is only one mediator
    {if(is.factor(nom1[,med]))              #added to control for one factor mediator
      marg.m<-as.factor(c(as.character(nom1[,med]),as.character(nom0[,med]))[temp.rand])
    else
      marg.m<-c(nom1[,med],nom0[,med])[temp.rand]
    }        
      else                                         #added for the new program
        marg.m<-rbind(nom1[,med],nom0[,med])[temp.rand,]
      new1<-nom1
      new0<-nom0
      if(length(med)==1)                                       #added for the new program, when there is only one mediator
      {new1[,med]<-marg.m[1:nrow(new1)]                     #added for the new program 
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0))]}  #added for the new program
      else                                                     #added for the new program
      {new1[,med]<-marg.m[1:nrow(new1),]
      new0[,med]<-marg.m[(nrow(new1)+1):(nrow(new1)+nrow(new0)),]}
      if(!is.null(xmod))
        for (z in med)
        {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
        m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0[,m.t1]=m.t2[,m.t]
        new1[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
      dir.nom<-NULL
      for (m in 1:length(full.model))
        if(surv[m] & !is.null(best.iter1[m]))
          dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T)
      else if(surv[m])
        dir.nom[m]<-mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T)
      else
        dir.nom[m]<-mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T)
      dir.nom
    }
    
    med.binx.catm<-function(full.model,nom1,nom0,med,best.iter1=NULL,surv,type,xmod,xnames)  
    {n3<-nrow(nom1)+nrow(nom0)
    temp.rand<-unlist(list(nom1[,med],nom0[,med]))[sample(1:n3,replace=T)]
    marg.m1<-temp.rand[1:nrow(nom1)]
    marg.m2<-temp.rand[(nrow(nom1)+1):n3]
    dir.nom<-rep(0,length(full.model))
    for (m in 1:length(full.model))
      for (i in levels(x[,med]))
      {new1<-nom1
      new1[1:dim(new1)[1],med]<-i
      new0<-nom0
      new0[1:dim(new0)[1],med]<-i
      if(!is.null(xmod))
      {temp.x=intersect(grep(xnames[med],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(new0,new0[,med],inter.cov=xmod)
      m.t3=form.interaction(new1,new1[,med],inter.cov=xmod)
      for (m.t1 in temp.x)
      {new0[,m.t1]=m.t2[,m.t]
      new1[,m.t1]=m.t3[,m.t]
      m.t=m.t+1}}
      }
      p<-mean(temp.rand==i,na.rm=T)
      if(surv[m] & !is.null(best.iter1[m]))
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m],type=type),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m],type=type),na.rm=T))
      else if(surv[m])
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,type=type),na.rm=T)- mean(predict(full.model[[m]],new0,type=type),na.rm=T))
      else
        dir.nom[m]<-dir.nom[m]+p*(mean(predict(full.model[[m]],new1,best.iter1[m]),na.rm=T)- mean(predict(full.model[[m]],new0,best.iter1[m]),na.rm=T))
      }
    dir.nom
    }
    
    #1.fit the model
    x2<-cbind(x,dirx)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    
    for (j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      x1<-x2[!is.na(y[,j]),]             #delete nas in y for mart
      y1<-y[!is.na(y[,j]),j]
      w1<-w[!is.na(y[,j])]
      if(!is.null(custom.function)){
        if(!is.na(custom.function[j])){
          cf1=gsub("responseY","y1",custom.function[j])
          cf1=gsub("dataset123","x1",cf1)
          cf1=gsub("weights123","w1",cf1)
          full.model[[j]]<-eval(parse(text=cf1))
        }
        else if (nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                   distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
        else
          full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
        }
      }
      else if (nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x1,y1, n.trees=200, interaction.depth=D, shrinkage=nu, w=w1,
                                                 distribution=distn[j],train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}}
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y1~., data=x1, weights=w1)
      else
        full.model[[j]]<-glm(y1~., data=x1, family=family1[[j]], weights=w1)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    te<-matrix(0,n,ncol(y)*ncol(dirx))
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
    if(!is.null(jointm))
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))+jointm[[1]]))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")
    }
    else
    {denm<-matrix(0,n,ncol(y)*(1+length(c(contm,catm))))
    dimnames(denm)[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".")
    }
    denm<-rep(list(denm),ncol(dirx))
    ie<-denm
    #3. repeat to get the mediation effect
    for (k in 1:n)
    {#3.1 get the te         full.model,x,y,dirx,best.iter1=NULL
      x0.temp<-apply(dirx==1,1,sum)==0  #indicator of the reference group
      x0<-x2[x0.temp,]
      if(is.null(w))
      {w1<-NULL
      w0<-NULL}
      else
        w0<-w[x0.temp]
      for (l in 1:ncol(dirx))  #l indicate the lth predictor
      {x1.2<-x2[dirx[,l]==1,]
      if(!is.null(w))
        w1<-w[dirx[,l]==1]
      #n3<-dim(x)[1] use the original size
      new1<-x1.2[sample(1:nrow(x1.2),replace=T,prob=w1),] #floor(n3/2),
      new0<-x0[sample(1:nrow(x0),replace=T,prob=w0),] #floor(n3/2),
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-te.binx(full.model,new1,new0,best.iter1,surv,type)  
      temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
      #the indirect effect of all mediators
      temp.ie<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-med.binx.jointm(full.model,new1,new0,allm,best.iter1,surv,type,temp.rand,xmod,xnames) #add temp.rand
      #new method to calculate the direct effect     
       x.temp=data.frame(x[dirx[,l]==1 | x0.temp,])
      new1.temp=data.frame(x.temp[temp.rand[1:nrow(x1.2)],],dirx[dirx[,l]==1,])
      new0.temp=data.frame(x.temp[temp.rand[(nrow(x1.2)+1):(nrow(x1.2)+nrow(x0))],],dirx[x0.temp,])
      colnames(new1.temp)<-c(xnames,pred_names)
      colnames(new0.temp)<-c(xnames,pred_names)
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new0.temp,dirx[x0.temp,],inter.cov=xmod)
        m.t3=form.interaction(new1.temp,dirx[dirx[,l]==1,],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new0.temp[,m.t1]=m.t2[,m.t]
        new1.temp[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}}
      denm[[l]][k,1:ncol(y)]<-te.binx(full.model,new1.temp,new0.temp,best.iter1,surv,type) #add temp.rand
      
      j<-2
      #3.2 mediation effect from the continuous mediator
      if (!is.null(contm))
        for (i in contm)          #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.contm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.3.mediation effect from the categorical mediator
      if (!is.null(catm))
        for (i in catm)           #full.model,x,y,med,dirx,best.iter1=NULL
        {denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.catm(full.model,new1,new0,i,best.iter1,surv,type,xmod,xnames)
        j<-j+1}
      #3.4 mediation effect from the joint mediators
      if (!is.null(jointm))
        for (i in 1:jointm[[1]])          #full.model,x,y,med,dirx,best.iter1=NULL
        {temp.rand<-sample(1:(nrow(x1.2)+nrow(x0)),replace=T)# no need for:prob=c(w1,w0) --redundant
        denm[[l]][k,(ncol(y)*(j-1)+1):(ncol(y)*j)]<-med.binx.jointm(full.model,new1,new0,jointm[[i+1]],best.iter1,surv,type,temp.rand,xmod,xnames)
        j<-j+1}
      #3.5 get the indirect effects and total effect
      ie[[l]][k,]<-te[k,((l-1)*ncol(y)+1):(l*ncol(y))]-denm[[l]][k,]
      ie[[l]][k,1:ncol(y)]<-temp.ie
      te[k,((l-1)*ncol(y)+1):(l*ncol(y))]<-denm[[l]][k,1:ncol(y)]+temp.ie
      
      if(!is.null(jointm))
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ncol(y)),sep=".")#c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep=""))
      else
        dimnames(ie[[l]])[[2]]<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ncol(y)),sep=".") #c("all",colnames(x)[c(contm,catm)])
      }
    }
    names(denm)<-pred_names
    names(ie)<-pred_names
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear, Survival=surv, type=type, model=full.model,best.iter=best.iter1),data=data)
    class(a)<-"med"
    return(a)
  }
  
  if (is.null(c(contm,catm)))
    stop("Error: no potential mediator is specified")
  
  #set.seed(seed)
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  if(!is.null(cova)){
    if( length(grep("for.m",names(cova)))==0)
    cova_names=colnames(cova)
  else 
    cova_names=colnames(cova[[1]])}
  ynames=colnames(y)
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(catm))
    catm<-unlist(sapply(catm,grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  allm=c(contm,catm)
  ny=ncol(y)
  nx=ncol(dirx)
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  if(is.null(jointm))
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))))
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)]),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  else 
  {ie<-matrix(0,n2,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  ie1<-matrix(0,nx,ny*(1+length(c(contm,catm))+jointm[[1]]))
  dimnames(ie1)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[c(contm,catm)],paste("j",1:jointm[[1]],sep="")),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names
  temp<-med.binx(data=NULL,x,y,dirx,contm,catm,jointm,cova,allm,n,nonlinear,nu,D,distn,family1,biny,refy,surv,type,w=w,xmod,custom.function)
  te[1,]<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie1[l,]<-apply(temp$ie[[l]],2,mean)}  #first row is the estimated value
  de[1,]<-apply(temp.1,2,mean,na.rm=T)
  model<-temp$model
  best.iter<-temp$best.iter
  
  registerDoParallel(cores=ncore)
  r<-foreach(i=1:n2,.combine=rbind,.packages =c('gbm','survival','splines','doParallel'))  %dopar% 
  {boots<-sample(1:nrow(x),replace=T,prob=w)
  x1<-data.frame(x[boots,])
  names(x1)=xnames
  y1<-data.frame(y[boots,])
  colnames(y1)=ynames
  pred1<-data.frame(dirx[boots,])
  colnames(pred1)=pred_names
  temp<-med.binx(data=NULL,x=x1, y=y1, dirx=pred1, contm=contm, catm=catm,jointm=jointm,cova=cova,allm=allm,n=n,
                 nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,biny=biny,refy=refy,surv=surv,type=type,w=NULL,xmod,custom.function=custom.function)
  te1<-apply(temp$te,2,mean,na.rm=T)
  temp.1<-NULL
  ie1<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  ie1<-c(ie1,apply(temp$ie[[l]],2,mean,na.rm=T))}  #first row is the estimated value
  de1<-apply(temp.1,2,mean,na.rm=T)
  c(te1,de1,ie1)  
  }
  
  nxy=ny*nx
  nie=ncol(ie1)
  te[2:(n2+1),]<-r[,1:nxy]
  de[2:(n2+1),]<-r[,(nxy+1):(2*nxy)]
  temp.col<-2*nxy
  for (l in 1:nx)
  {ie[[l]][1:n2,]<-r[,(temp.col+1):(temp.col+nie)]
  temp.col<-temp.col+nie}
  
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model, 
          data=list(x=x,y=y,dirx=dirx,contm=contm,catm=catm,jointm=jointm,cova=cova, binpred=T),mod=F)
  class(a)<-"mma"
  return(a)
}

boot.med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,
                         catm=data$catm, jointm=data$jointm,cova=data$cova, margin=1, n=20,
                         nonlinear=F,df1=1,nu=0.001,D=3,distn="gaussian",
                         family1=gaussian(link="identity"),n2=50,
                         w=rep(1,nrow(x)),biny=(data$y_type==2),refy=rep(NA,ncol(y)),
                         x.new=x,pred.new=dirx,cova.new=cova,surv,type,w.new=NULL,ncore=NULL,xmod=NULL,custom.function=NULL)
{
  med.contx<-function(data,x=data$x,y=data$y,dirx=data$dirx,binm=data$binm,contm=data$contm,
                      catm=data$catm, jointm=data$jointm, cova=data$cova, margin=1, n=20,
                      nonlinear=F,df1=1,nu=0.001,D=3,distn=NULL,family1=data$family1,
                      biny=(data$y_type==2),refy=rep(NA,ncol(y)),x.new=x,pred.new=dirx, cova.new=cova, surv=(data$y_type==4),
                      type=NULL,w=NULL, w.new=NULL, xmod=NULL,custom.function=NULL)
  {if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
    # browser()
    xnames<-colnames(x)
    pred_names<-colnames(dirx)
    ynames<-colnames(y)
    if(!is.null(cova)) {
      if(length(grep("for.m",names(cova)))==0)
        cova_names=colnames(cova)
      else 
        cova_names=colnames(cova[[1]])}
    if(is.character(contm))
      contm<-unlist(sapply(contm,grep,xnames))
    if(is.character(binm))
      binm<-unlist(sapply(binm,grep,xnames))
    if(!is.null(catm))
      for (i in 2:length(catm))
        if(is.character(catm[[i]]))
          catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
    if(!is.null(jointm))
      for (i in 2:length(jointm))
        if(is.character(jointm[[i]]))
          jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
    
    anymissing<-function(vec) #return T if there is any missing in the vec
    {if(sum(is.na(vec))>0)
      return(F)
      else return(T)
    }
    
    col_mean<-function(col,n.row,w=NULL)
    {temp<-matrix(col,n.row)
    if(is.null(w))
      return(apply(temp,1,mean,na.rm=T))
    else
      return(apply(temp,1,weighted.mean,na.rm=T,w=w))}
    
    
    dist.m.given.x<-function(x,dirx,binm=NULL,contm=NULL,catm=NULL,nonlinear,df1,w,cova) #give the model and residual of m given x
    {
      getform=function(z,nonlinear,df1)
      {if(!nonlinear)
        formu="x[,i]~."
      else
      {names.z=colnames(z)
      temp.t=unlist(lapply(z,is.character)) | unlist(lapply(z,is.factor))
      names.z1=names.z[!temp.t]
      names.z2=names.z[temp.t]
      if(length(names.z1)==0)
        formu="x[,i]~."
      else if (length(names.z2)==0)
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),sep="")
      else
        formu=paste("x[,i]~",paste(paste("ns(",names.z1,",","df=",df1,")",sep=""),collapse="+"),"+",
                    paste(names.z2,collapse="+"),sep="")
      }
      formu
      }
      #browser()  
      models<-NULL
      x=data.frame(x)
      res<-NULL
      temp.namec=colnames(x)
      indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
      if(!is.null(cova))
        if(length(grep("for.m",names(cova)))!=0)
          for (i in 1:length(cova[[2]]))
            indi=c(indi,grep(cova[[2]][i],temp.namec))
      if(!is.null(catm))
      {for (i in 2:(catm$n+1))
        binm<-c(binm,catm[[i]])}
      
      z<-dirx
      z.name=paste("predictor",1:ncol(z),sep=".")
      colnames(z)=z.name
      # browser()
      if(!is.null(cova))
      {if (length(grep("for.m",names(cova)))==0)#create the predictor matrix z
        z<-cbind(z,cova)
      else 
      {
        z1<-cbind(z,cova[[1]])
        form1=getform(z1,nonlinear,df1)
      }}
      
      form0=getform(z,nonlinear,df1)
      j<-1
      
      if(!is.null(binm))
      {for(i in binm)
      {if(!i%in%indi)
      {models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=binomial(link = "logit"),weights=w)
      res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z=z)))}
        else
        {models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=binomial(link = "logit"),weights=w)
        res<-cbind(res,x[,i]-predict(models[[j]],type = "response",newdata=data.frame(z=z1)))}
        j<-j+1}
      }
      # browser()
      for (i in contm)
      {if(!i%in%indi)
        models[[j]]<-glm(as.formula(form0),data=data.frame(z),family=gaussian(link="identity"),weights=w)
      else
        models[[j]]<-glm(as.formula(form1),data=data.frame(z1),family=gaussian(link="identity"),weights=w)
      res<-cbind(res,models[[j]]$res)
      j<-j+1
      }
      list(models=models,varmat=var(res))
    }
    
    
    sim.xm<-function(distmgivenx,x1,dirx,binm,contm,catm,nonlinear,df1,cova)  #added nonlinear and df1 to sim.xm
    {mult.norm<-function(mu,vari,n) 
    {if (nrow(vari)!=ncol(vari)) 
      result<-c("Error: Variance matrix is not square")  
    else if (length(mu)!=nrow(vari)) 
      result<-c("Error: length mu is not right!")  
    else {   p<-length(mu)
    tmp1<-eigen(vari)$values
    tmp2<-eigen(vari)$vectors   
    result<-matrix(0,n,p)   
    for (i in 1:p)
    {result[,i]<-rnorm(n,mean=0,sd=sqrt(tmp1[i]))}   
    for (i in 1:n)
    {result[i,]<-tmp2%*%result[i,]+mu}
    }  
    result
    }
    
    match.margin<-function(vec)   
    {range1<-vec[1:2]
    vec1<-vec[-(1:2)]
    range2<-range(vec1,na.rm=T)
    vec1<-range1[1]+diff(range1)/diff(range2)*(vec1-range2[1])
    vec1
    }
    
    gen.mult<-function(vec)
    {if(sum(is.na(vec))>0)
      return(rep(NA,length(vec)))
      else{ 
        l<-1-sum(vec)
        l<-ifelse(l<0,0,l)
        return(rmultinom(1,size=1,prob=c(l,vec))[-1])}
    }
    
    x1=data.frame(x1)
    temp.namec=colnames(x1)
    indi=NULL                               #indi indicate if not all mediators, the columns of mediators that needs covariates
    if(!is.null(cova))
      if(length(grep("for.m",names(cova)))!=0)
        for (i in 1:length(cova[[2]]))
          indi=c(indi,grep(cova[[2]][i],temp.namec))
    
    means<-NULL
    z<-dirx
    z.name=paste("predictor",1:ncol(z),sep=".")
    colnames(z)=z.name
    
    if(!is.null(cova))
    {if(length(grep("for.m",names(cova)))==0)   #create the predictor matrix z
      z<-cbind(z,cova)
    else 
      z1<-cbind(z,cova[[1]])}
    
    binm1<-binm
    
    if(!is.null(catm))
    {for (i in 2:(catm$n+1))
      binm1<-c(binm1,catm[[i]])}
    if(!is.null(binm1))
      for (i in 1:length(binm1))
      {if(binm1[i]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z1)))
      else  
        means<-cbind(means,predict(distmgivenx$models[[i]],type = "response",newdata=data.frame(z)))}
    if(!is.null(contm))
      for (i in (length(binm1)+1):length(c(binm1,contm)))
      {if(contm[i-length(binm1)]%in%indi)
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z1)))
      else
        means<-cbind(means,predict(distmgivenx$models[[i]],newdata=data.frame(z)))}
    
    if(dim(means)[2]==1)                                                   #added in the new program, in case there is only one mediator
    {sim.m<-suppressWarnings(rnorm(length(means),mean=means,sd=sqrt(distmgivenx$varmat)))     #added in the new program
    sim.m2<-match.margin(c(range(means,na.rm=T),sim.m))}                          #added in the new program   
    else{
      sim.m<-t(apply(means,1,mult.norm,vari=distmgivenx$varmat,n=1))
      
      range.means<-apply(means,2,range,na.rm=T)
      
      sim.m2<-apply(rbind(range.means,sim.m),2,match.margin)    #to make the simulate fit the means' ranges
    }
    sim.m2<-data.frame(sim.m2)
    n<-dim(sim.m2)[1]
    if(!is.null(binm))
      for (i in 1:length(binm))
        sim.m2[,i]<-rbinom(n,size=1,prob=sim.m2[,i])
    
    if(!is.null(catm))
    {j<-length(binm)+1
    for (i in 2:(catm$n+1))
    {a<-sim.m2[,j:(j+length(catm[[i]])-1)]
    sim.m2[,j:(j+length(catm[[i]])-1)]<-t(apply(a,1,gen.mult))
    j<-j+length(catm[[i]])}
    }
    
    x1[,c(binm1,contm)]<-sim.m2
    
    x1
    }
    
    if(is.null(catm))
      multi=jointm
    else if(is.null(jointm))
      multi=catm
    else {temp1<-catm
    temp2<-jointm
    temp1[[1]]=catm[[1]]+jointm[[1]]
    temp2[[1]]<-NULL
    multi=append(temp1,temp2)} 
    listm=list(single=c(contm,binm),multi=multi)
    
    if (is.null(multi))                      #allm list all mediators
    {tempm<-multi
    tempm[[1]]<-NULL}
    else  tempm<-NULL
    allm<-unique(c(contm,binm,unlist(tempm)))
    nonmissing<-apply(cbind(y,x[,listm$single],dirx),1,anymissing)
    temp.name1=colnames(x)
    x<-data.frame(x[nonmissing,])
    colnames(x)=temp.name1
    y<-data.frame(y[nonmissing,])
    if(!is.null(cova))
    {cova=data.frame(cova[nonmissing,])
    colnames(cova)=cova_names}
    colnames(y)<-ynames
    pred<-data.frame(dirx[nonmissing,])
    colnames(pred)<-pred_names
    w<-w[nonmissing]
    nonmissing1<-apply(cbind(x.new[,listm$single],pred.new),1,anymissing)
    temp.name1=colnames(x.new)
    x.new<-data.frame(x.new[nonmissing1,])
    colnames(x.new)=temp.name1
    w.new<-w.new[nonmissing1]
    pred.new<-data.frame(pred.new[nonmissing1,])
    colnames(pred.new)<-pred_names
    if(!is.null(cova.new))  
    {cova.new=data.frame(cova.new[nonmissing,])
    colnames(cova.new)=cova_names}
    
    #1.fit the model
    x2<-cbind(x,pred)
    colnames(x2)<-c(xnames,pred_names)
    full.model<-NULL
    best.iter1<-NULL
    for(j in 1:ncol(y)){
      if(biny[j])                     #recode y if y is binary
        y[,j]<-ifelse(y[,j]==refy[j],0,1)
      
      if(!is.null(custom.function))
      { if(!is.na(custom.function[j]))
      {cf1=gsub("responseY","y[,j]",custom.function[j])
      cf1=gsub("dataset123","x2",cf1)
      cf1=gsub("weights123","w",cf1)
      full.model[[j]]<-eval(parse(text=cf1))}
        else if(nonlinear)
        {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                   distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
        while(full.model[[j]]$n.trees-best.iter1[j]<30){
          full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
          best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
        }
        else
        {if(surv[j])
          full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
        else
          full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
        }
      }
      else if(nonlinear)
      {full.model[[j]]<-suppressWarnings(gbm.fit(x2,y[,j], n.trees=200, interaction.depth=D, shrinkage=nu,w=w,
                                                 distribution=distn,train.fraction=1.0, bag.fraction=0.5, verbose=FALSE))
      best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))         
      while(full.model[[j]]$n.trees-best.iter1[j]<30){
        full.model[[j]]<-suppressWarnings(gbm.more(full.model[[j]], 100))           # do another 50 iterations
        best.iter1[j]<-suppressWarnings(gbm.perf(full.model[[j]],plot.it=FALSE,method="OOB"))}
      }
      else
      {if(surv[j])
        full.model[[j]]<-coxph(y[,j]~., data=x2, weights=w)
      else
        full.model[[j]]<-glm(y[,j]~., data=x2, family=family1[[j]], weights=w)
      }
    }
    
    #2. prepare for the store of results
    #set.seed(seed)
    n.new<-nrow(x.new)
    
    #3. get the joint distribution of m given x
    distmgivenx<-dist.m.given.x(x,pred,binm,contm,catm,nonlinear,df1,w,cova)
    te1.0<-NULL
    denm1.0<-NULL
    denm1.1<-NULL
    n1<-dim(x)[1]
    
    #4. repeat to get the mediation effect
    for (l in 1:ncol(pred)) {
      denm1<-NULL
      denm1.2=NULL
      te1<-NULL
      for (k in 1:n)
      {new0<-sim.xm(distmgivenx,x.new,pred.new,binm,contm,catm,nonlinear,df1,cova.new) #draw ms conditional on x.new
      temp.pred<-pred.new
      temp.pred[,l]<-temp.pred[,l]+margin
      if(!is.null(xmod))   #allows the interaction of pred with xmod
      {cova.new1=cova.new
      x.new1=x.new
      if(!is.null(cova.new))
      {temp.cova=intersect(grep(pred_names[l],cova_names),grep(xmod,cova_names))
      if(sum(temp.cova)>0)
      {m.t=1
      m.t2=form.interaction(cova.new,temp.pred[,l],inter.cov=xmod)
      for (m.t1 in temp.cova)
      {cova.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}
      }}
      temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
      if(sum(temp.x)>0)
      {m.t=1
      m.t2=form.interaction(x.new,temp.pred[,l],inter.cov=xmod)
      for (m.t1 in temp.x)
      {x.new1[,m.t1]=m.t2[,m.t]
      m.t=m.t+1}}
      new1<-sim.xm(distmgivenx,x.new1,temp.pred,binm,contm,catm,nonlinear,df1,cova.new1)  #draw from the conditional distribution of m given x
      }
      else
        new1<-sim.xm(distmgivenx,x.new,temp.pred,binm,contm,catm,nonlinear,df1,cova.new)  #draw from the conditional distribution of m given x
      new1<-cbind(new1,temp.pred)   #draw ms conditional on x.new+margin
      new0<-cbind(new0,pred.new) 
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new0,new0[,z],inter.cov=xmod)
          m.t3=form.interaction(new1,new1[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new0[,m.t1]=m.t2[,m.t]
          new1[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      denm2<-NULL
      
      #browser()   
      
      sample.temp<-sample(1:n.new,2*n.new,replace = T,prob=w.new)   #random sample from the original data
      
      #4.0.0 get the total indirect effect
      temp.new1<-new1
      temp.new1[,allm]<-x.new[sample.temp[1:n.new],allm]
      temp.new0<-new0
      temp.new0[,allm]<-x.new[sample.temp[(n.new+1):(2*n.new)],allm]
      
      if(!is.null(xmod))
        for(z in allm){
          temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(x.new[sample.temp[1:n.new],],x.new[sample.temp[1:n.new],z],inter.cov=xmod)
          m.t3=form.interaction(x.new[sample.temp[(n.new+1):(2*n.new)],],x.new[sample.temp[(n.new+1):(2*n.new)],z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {temp.new1[,m.t1]=m.t2[,m.t]
          temp.new0[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
        }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin
      else if(surv[m])
        denm3<-(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin
      else
        denm3<-(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin
      
      #4.0 get the direct effect
      temp.new1<-x.new[sample.temp[1:n.new],]
      temp.new1=cbind(temp.new1,temp.pred)
      temp.new0<-x.new[sample.temp[(n.new+1):(2*n.new)],]
      temp.new0=cbind(temp.new0,pred.new)
      colnames(temp.new1)<-c(xnames,pred_names)
      colnames(temp.new0)<-c(xnames,pred_names)
      
      if(!is.null(xmod)){
        temp.x=intersect(grep(pred_names[l],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(temp.new1,temp.pred[,l],inter.cov=xmod)
        m.t3=form.interaction(temp.new0,pred.new[,l],inter.cov=xmod)
        for (m.t1 in temp.x)
        {temp.new1[,m.t1]=m.t2[,m.t]
        temp.new0[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
      }
      
      for (m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m],type=type)-predict(full.model[[m]],temp.new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,type=type)-predict(full.model[[m]],temp.new0,type=type))/margin)
      else
        denm2<-cbind(denm2,(predict(full.model[[m]],temp.new1,best.iter1[m])-predict(full.model[[m]],temp.new0,best.iter1[m]))/margin)
      
      #4.1 get the te
      te0<-NULL
      for(m in 1:ncol(y))
        if(surv[m] & !is.null(best.iter1[m]))
          te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m],type=type)-predict(full.model[[m]],new0,best.iter1[m],type=type))/margin)
      else if(surv[m])
        te0<-c(te0, (predict(full.model[[m]],new1,type=type)-predict(full.model[[m]],new0,type=type))/margin)
      else
        te0<-c(te0, (predict(full.model[[m]],new1,best.iter1[m])-predict(full.model[[m]],new0,best.iter1[m]))/margin)
      te1<-cbind(te1,te0)
      
      #4.2 mediation effect from the single mediator
      # browser()
      if (!is.null(listm$single))
        for (i in 1:length(listm$single))
        {new1.nm<-new1
        new0.nm<-new0
        temp.m<-x.new[sample.temp,listm$single[i]]
        new1.nm[,listm$single[i]]<-temp.m[1:n.new]    #draw m from its original distribution
        new0.nm[,listm$single[i]]<-temp.m[(n.new+1):(2*n.new)]    #draw m from its original distribution
        
        if(!is.null(xmod))
        {temp.x=intersect(grep(xnames[listm$single[i]],xnames),grep(xmod,xnames))
        if(sum(temp.x)>0)
        {m.t=1
        m.t2=form.interaction(new1.nm,new1.nm[,listm$single[i]],inter.cov=xmod)
        m.t3=form.interaction(new0.nm,new0.nm[,listm$single[i]],inter.cov=xmod)
        for (m.t1 in temp.x)
        {new1.nm[,m.t1]=m.t2[,m.t]
        new0.nm[,m.t1]=m.t3[,m.t]
        m.t=m.t+1}}
        }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      
      #4.3.mediation effect from the joint mediator
      if (!is.null(listm$multi))
        for (i in 2:(listm$multi[[1]]+1))
        {new1.nm<-new1
        new0.nm<-new0
        new1.nm[,listm$multi[[i]]]<-x.new[sample.temp[1:n.new],listm$multi[[i]]]    #draw m from its original distribution
        new0.nm[,listm$multi[[i]]]<-x.new[sample.temp[(n.new+1):(2*n.new)],listm$multi[[i]]]    #draw m from its original distribution
        
        if(!is.null(xmod))
          for (z in listm$multi[[i]])
          {temp.x=intersect(grep(xnames[z],xnames),grep(xmod,xnames))
          if(sum(temp.x)>0)
          {m.t=1
          m.t2=form.interaction(new1.nm,new1.nm[,z],inter.cov=xmod)
          m.t3=form.interaction(new0.nm,new0.nm[,z],inter.cov=xmod)
          for (m.t1 in temp.x)
          {new1.nm[,m.t1]=m.t2[,m.t]
          new0.nm[,m.t1]=m.t3[,m.t]
          m.t=m.t+1}}
          }
        
        for(m in 1:ncol(y))
          if(surv[m] & !is.null(best.iter1[m]))
            denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m],type=type)-predict(full.model[[m]],new0.nm,best.iter1[m],type=type))/margin)
        else if(surv[m])
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,type=type)-predict(full.model[[m]],new0.nm,type=type))/margin)
        else
          denm2<-cbind(denm2,(predict(full.model[[m]],new1.nm,best.iter1[m])-predict(full.model[[m]],new0.nm,best.iter1[m]))/margin)
        }
      denm1<-rbind(denm1,denm2)
      denm1.2=rbind(denm1.2,as.matrix(denm3))
      }
      denm1.0[[l]]<-denm1 
      denm1.1[[l]]<-denm1.2 
      te1.0[[l]]<-te1
    } 
    
    #4.4 get the indirect effects
    denm<-NULL
    denm1<-NULL
    te<-NULL
    ie<-NULL
    for (l in 1:ncol(pred))
    {denm[[l]]<-apply(denm1.0[[l]],2,col_mean,n.new)
    denm1[[l]]<-apply(denm1.1[[l]],2,col_mean,n.new)
    te0<-matrix(apply(te1.0[[l]],1,mean),n.new)
    #te<-cbind(te,te0)
    temp1<-ncol(denm[[l]])/ncol(te0)
    temp2<-NULL
    for(temp in 1:temp1)
      temp2<-cbind(temp2,te0)
    ie[[l]]<-temp2-denm[[l]]
    ie[[l]][,1:ncol(y)]=matrix(rep(te0,ncol(y)),ncol=ncol(y))-denm1[[l]]      #the total indirect effect
    te=cbind(te,ie[[l]][,1:ncol(y)]+denm[[l]][,1:ncol(y)])                    #the total effect
    if(!is.null(listm$multi)) 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(denm[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("de",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    if(!is.null(listm$multi))
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single],paste("j",1:listm$multi[[1]],sep="")),each=ncol(y)),sep=".")
    else 
      colnames(ie[[l]])<-paste(paste("y",1:ncol(y),sep=""),rep(c("all",colnames(x)[listm$single]),each=ncol(y)),sep=".")
    }
    colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
    names(denm)<-pred_names
    names(ie)<-pred_names
    a<-list(denm=denm,ie=ie,te=te,model=list(MART=nonlinear,Survival=surv, type=type, model=full.model,best.iter=best.iter1),pred.new=pred.new,w.new=w.new,data=data,distmgivenx=distmgivenx)
    class(a)<-"med"
    return(a)
  }
  
  anymissing<-function(vec)
  {if(sum(is.na(vec))>0)
    return(F)
    else return(T)
  }
  
  col_mean1<-function(col,n.row,w=NULL)
  {temp<-matrix(col,n.row)
  if(is.null(w))
    return(apply(temp,2,mean,na.rm=T))
  else
    return(apply(temp,2,weighted.mean,na.rm=T,w=w))}
  
  stock<-function(mat,rows)
  {if(nrow(mat)==rows)
    temp=mat
  else{
    temp<-mat[1:rows,]
    temp1=rows
    while(temp1<nrow(mat))   
    {temp<-cbind(temp,mat[(temp1+1):(temp1+rows),])
    temp1<-temp1+rows}
  }
  temp
  }
  
  if (is.null(c(binm,contm,catm)))
    stop("Error: no potential mediator is specified")
  
  #set.seed(seed)
  xnames<-colnames(x)
  pred_names<-colnames(dirx)
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
    cova_names=colnames(cova)
  else 
    cova_names=colnames(cova[[1]])}
  ynames=colnames(y)
  if(is.character(contm))
    contm<-unlist(sapply(contm,grep,xnames))
  if(is.character(binm))
    binm<-unlist(sapply(binm,grep,xnames))
  if(!is.null(catm))
    for (i in 2:length(catm))
      if(is.character(catm[[i]]))
        catm[[i]]<-unlist(sapply(catm[[i]],grep,xnames))
  if(!is.null(jointm))
    for (i in 2:length(jointm))
      if(is.character(jointm[[i]]))
        jointm[[i]]<-unlist(sapply(jointm[[i]],grep,xnames))
  
  if(is.null(catm))
  {multi=jointm
  name1<-NULL                       #added in the new program
  if (!is.null(multi))              #added in the new program, in case that multi is NULL
    name1<-paste("j",1:multi[[1]],sep="")}
  else if(is.null(jointm))
  {multi=catm
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])}
  else {temp1<-catm
  temp2<-jointm
  temp1[[1]]=catm[[1]]+jointm[[1]]
  temp2[[1]]<-NULL
  multi=append(temp1,temp2)
  name1<-NULL
  for (i in 2:(catm[[1]]+1))
    name1<-c(name1,colnames(x)[multi[[i]][1]])
  name1<-c(name1,paste("j",1:jointm[[1]],sep=""))} 
  listm=list(single=c(contm,binm),multi=multi)
  
  ny=ncol(y)
  nx=ncol(dirx)
  te<-matrix(0,n2+1,ny*nx)
  de<-matrix(0,n2+1,ny*nx)
  mul<-ifelse(is.null(multi),0,multi[[1]])        #added in the new program, in case multi is null
  ie<-matrix(0,n2,ny*(1+length(listm$single)+mul))   #added in the new program
  ie1<-matrix(0,nx,ny*(1+length(listm$single)+mul))   #added in the new program
  if(!is.null(listm$multi))
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single],name1),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  else 
  {dimnames(ie)[[2]]<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  colnames(ie1)<-paste(paste("y",1:ny,sep=""),rep(c("all",colnames(x)[listm$single]),each=ny),sep=".")
  rownames(ie1)<-pred_names}
  ie<-rep(list(ie),nx)
  names(ie)<-pred_names
  
  temp.med<-med.contx(data=NULL,x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova, 
                  margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,distn=distn,family1=family1,biny=biny,
                  refy=refy,x.new=x.new,pred.new=pred.new, cova.new=cova.new, surv,type,w=w,w.new=w.new,xmod=xmod,custom.function=custom.function)
  temp=temp.med
  temp.1<-NULL
  for (l in 1:nx)
    temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  if(is.null(w.new))
  {te[1,]<-apply(temp$te,2,mean,na.rm=T)
  de[1,]<-apply(temp.1,2,mean,na.rm=T) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,mean,na.rm=T)  #first row is the estimated value
  }
  else
  {te[1,]<-apply(temp$te,2,weighted.mean,na.rm=T,w=w.new)
  de[1,]<-apply(temp$denm[,1],2,weighted.mean,na.rm=T,w=w.new) 
  for (l in 1:nx)
    ie1[l,]<-apply(temp$ie[[l]],2,weighted.mean,na.rm=T,w=w.new)  #first row is the estimated value
  }
  
  te1<-NULL                      #to store the mediation effects on predictor
  de1<-NULL
  ie2<-rep(list(NULL),nx)
  names(ie2)<-pred_names
  model<-temp$model
  
  registerDoParallel(cores=ncore)
  l<-1
  r<-foreach(l=1:n2, .combine=rbind,.packages =c('gbm','survival','splines','doParallel'))  %dopar% 
  {boots<-sample(1:nrow(x),replace=T, prob=w)
  x1<-data.frame(x[boots,])
  colnames(x1)=xnames
  y1<-data.frame(y[boots,])
  colnames(y)=ynames
  dirx1<-data.frame(dirx[boots,])
  colnames(dirx1)=pred_names
  if(!is.null(cova)){
    if(length(grep("for.m",names(cova)))==0)
  {cova1<-data.frame(cova[boots,])
  colnames(cova1)=cova_names}
  else
  {cova1=cova
  cova1[[1]]=data.frame(cova[[1]][boots,])
  colnames(cova1[[1]])=cova_names
  names(cova1[[1]])=names(cova[[1]])}}
  else
    cova1=NULL  
  
  temp<-med.contx(data=NULL,x=x1,y=y1,dirx=dirx1,binm=binm,contm=contm,catm=catm,jointm=jointm,cova=cova1, 
                  margin=margin,n=n,nonlinear=nonlinear,df1=df1,nu=nu,D=D,
                  distn=distn,family1=family1,biny=biny,refy=refy,x.new=x.new,pred.new=pred.new,
                  cova.new=cova.new,surv=surv,type=type,xmod=xmod,custom.function=custom.function) #added to the new codel, change the seed to make different results
  temp.1<-NULL
  temp.2<-NULL
  for (l in 1:nx)
  {temp.1<-cbind(temp.1,temp$denm[[l]][,1:ny])
  temp.2<-cbind(temp.2,temp$ie[[l]])}
  te1<-temp$te  #n*nxy
  de1<-temp.1   #n*nxy
  ie1<-temp.2   #n*(nxy*nie)
  cbind(te1,de1,ie1)
  }
  nxy=nx*ny
  te1<-stock(as.matrix(r[,1:nxy]),nrow(x.new))
  de1<-stock(as.matrix(r[,(1+nxy):(2*nxy)]),nrow(x.new))
  nie<-ncol(ie[[1]])
  temp.count<-2*nxy
  for(l in 1:nx)
  {ie2[[l]]<-r[,(temp.count+1):(temp.count+nie)]
  temp.count=temp.count+nie}
  
  if(is.null(w.new))
  {te[2:(n2+1),]<-matrix(apply(te1,2,mean,na.rm=T),ncol=nxy,byrow=T)
  de[2:(n2+1),]<-matrix(apply(de1,2,mean,na.rm=T),ncol=nxy,byrow=T)
  for (l in 1:nx)
    ie[[l]]<-apply(ie2[[l]],2,col_mean1,nrow(x.new))  #first row is the estimated value
  }
  else
  {te[2:(n2+1),]<-matrix(apply(te1,2,weighted.mean,na.rm=T,w=w.new),ncol=nxy,byrow=T)
  de[2:(n2+1),]<-matrix(apply(de1,2,weighted.mean,na.rm=T,w=w.new),ncol=nxy,byrow=T)
  for (l in 1:nx)
    ie[[l]]<-apply(ie2[[l]],2,col_mean1,nrow(x.new),w=w.new)  #first row is the estimated value
  }
  colnames(te)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  colnames(de)<-paste(paste("y",1:ncol(y),sep=""),rep(pred_names,each=ncol(y)),sep=".")
  missing.pred.new<-apply(pred.new,1,anymissing)
  pred.new<-data.frame(pred.new[missing.pred.new,])
  
  a<-list(estimation=list(ie=ie1,te=te[1,],de=de[1,]),bootsresults=list(ie=ie,te=te[-1,],de=de[-1,]),model=model,
          data=list(x=x,y=y,dirx=dirx,binm=binm,contm=contm,catm=catm, jointm=jointm, cova=cova, binpred=F),
          boot.detail=list(pred.new=pred.new,te1=te1,de1=de1,ie1=ie2),w.new=w.new,mod=F,med=temp.med)
  class(a)<-"mma"
  return(a)
}


data<-data.org(x=x,y=y,pred=pred,mediator=mediator,contmed=contmed,binmed=binmed,
               binref=binref,catmed=catmed,catref=catref,jointm=jointm,cova=cova,refy=refy,family1=family1,
               predref=predref,alpha=alpha,alpha2=alpha2,testtype=testtype, w=w)
biny=data$y_type==2
surv=data$y_type==4
if(sum(surv)>0 & is.null(type) & nonlinear)
  type="response"
else if (sum(surv)>0 & is.null(type))
  type="risk"
if(is.null(distn))
  distn<-rep(NA,ncol(data$y))
distn[is.na(distn) & data$y_type==2]="bernoulli"
distn[is.na(distn) & data$y_type==4]="coxph"
distn[is.na(distn) & data$y_type==1]="gaussian"

binpred<-data$binpred
family1<-data$family1

if(binpred) 
{result<-boot.med.binx(data=data,n=n,n2=n2,nonlinear=nonlinear,nu=nu,D=D,distn=distn,family1=family1,
                       w=w,biny=biny,refy=rep(0,ncol(data$y)),surv=surv,type=type,xmod=xmod,custom.function=custom.function)
}
else
{if(is.null(pred.new))
  result<-boot.med.contx(data=data,margin=margin, n=n, nonlinear=nonlinear,df1=df1, nu=nu,
                         D=D,distn=distn,family1=family1,n2=n2,w=w,biny=biny,refy=rep(0,ncol(data$y)),surv=surv,
                         type=type,xmod=xmod,custom.function=custom.function)
 else
  result<-boot.med.contx(data=data,margin=margin, n=n, nonlinear=nonlinear,df1=df1, nu=nu,
                         D=D,distn=distn,family1=family1,n2=n2,w=w,biny=biny,refy=0, x.new=x.new, 
                         pred.new=pred.new,cova.new=cova.new,surv=surv,type=type,w.new=w.new,xmod=xmod,custom.function=custom.function)
}
result
}

#############################################################################################
###############                         Moderation Analysis                    ##############
#Create the moderation function from med, may also be used with mma object, check later
test.moderation<-function(med1,vari,j=1,kx=NULL) #med1 is a med object from the med function, vari is the (vector of) potential moderators 
  #for nonlinear method and the interaction term(s) for linear method
  #j is the jth response if there are multiple responses
  #kx is the kth predictor if k=NULL means all predictor
{binarize<-function(varvec,ref=NULL) #binarize the categorical varvec, ref is the reference group, the first level if null
{a<-factor(varvec)
b=levels(a)
d<-matrix(0,length(varvec),length(b)-1)
if(is.null(ref))
{ref=b[1]
b=b[-1]}
else
  b=b[-grep(ref,b)]
for (k in 1:length(b))
  d[a==b[k],k]<-1
colnames(d)=b
d
}

if(!med1$model$MART)  #if the linear method is used
{temp=Anova(med1$model$model[[j]],type="III")
if(length(vari)==1)
  ln=grep(vari,rownames(temp))
else 
{ln=NULL
for(i in 1:length(vari))
  ln=c(ln,grep(vari[i],rownames(temp)))}
print(temp[ln,])}
else
{temp.name=c(colnames(med1$data$x),colnames(med1$data$dirx))
x=cbind(med1$data$x,med1$data$dirx)
nx=length(temp.name)
for(i in 1:length(vari))
{if(is.factor(x[,vari[i]]) | is.character(x[,vari[i]]))
  a=binarize(x[,vari[i]])
else
  a=as.matrix(x[,vari[i]])
if(is.null(kx))
  kx=1:ncol(med1$data$dirx)
for(l in 1:ncol(a))
  for (k in kx)
    x=cbind(x,a[,l]*med1$data$dirx[,k])
  temp.name=c(temp.name,paste(rep(paste(vari[i],colnames(a),sep=""),each=length(kx)),
                              rep(colnames(med1$data$dirx),ncol(a)),sep="."))
}
colnames(x)=temp.name 
y=med1$data$y[,j]
if(med1$model$Survival[j] & is.null(med1$data$w))
  model=coxph(y~.,data=x)
else if(med1$model$Survival[j])
  model=coxph(y~.,data=x,weights=med1$data$w)
else
  model=glm(y~.,data=x,family=med1$data$family1[[j]],weights=med1$data$w)
temp=Anova(model,type="III")
print(temp[(nx+1):(ncol(x)),])
cat("\nThe H-statistics on MART:\n")
namesdirx=colnames(med1$data$dirx)
for (i in kx)
  for (l in 1:length(vari))
    cat(paste("between ",vari[l]," and ",namesdirx[i],":",sep=""),
        interact.gbm(med1$model$model[[j]],cbind(med1$data$x,med1$data$dirx),i.var=c(namesdirx[i],vari[l])), "\n")
}
}



  
