# Setwd 
setwd("~/Downloads/AnalyticsVidya-July2016")

# Load the libraries 
library(dplyr)
library(data.table)
library(lubridate)
library(sqldf)
library(ggplot2)
library(corrplot)
library(xgboost)

# Load the data
train <- fread("Train_pjb2QcD.csv")
test <- fread("Test_wyCirpO.csv")

test <- mutate(test, Business_Sourced = 2)

# Combine Test and Train Data 
Traintest <- rbind(train,test)
str(Traintest)
summary(Traintest)


# Cleaning Features - Applicant 
summary(as.factor(Traintest$Office_PIN))
summary(as.factor(Traintest$Applicant_City_PIN)) # 131 NA's
summary(as.factor(Traintest$Applicant_Gender))
summary(as.factor((Traintest$Applicant_Marital_Status)))
summary(as.factor(Traintest$Applicant_Occupation))
summary(as.factor(Traintest$Applicant_Qualification))

Traintest$Applicant_Qualification[Traintest$Applicant_Qualification == ""] <- "Class XII"
Traintest$Applicant_Occupation[Traintest$Applicant_Occupation == ""] <- "Salaried"
Traintest$Applicant_Gender[Traintest$Applicant_Gender == ""] <- "M" # Male
Traintest$Applicant_Marital_Status[Traintest$Applicant_Marital_Status == ""] <- "M" # Married


# Cleaning Features - Manager
summary(as.factor(Traintest$Manager_Joining_Designation))
summary(as.factor(Traintest$Manager_Current_Designation))
summary(as.factor(Traintest$Manager_Grade))
table(Traintest$Manager_Grade,Traintest$Manager_Joining_Designation)
table(Traintest$Manager_Grade,Traintest$Manager_Current_Designation)
table(Traintest$Manager_Current_Designation,Traintest$Manager_Joining_Designation)
table(Traintest$Manager_Current_Designation,Traintest$Manager_Status)
table(Traintest$Manager_Joining_Designation,Traintest$Manager_Status,Traintest$Manager_Current_Designation)
table(Traintest$Manager_Grade,Traintest$Manager_Status)
summary(as.factor(Traintest$Manager_Gender))

Traintest$Manager_Joining_Designation[Traintest$Manager_Joining_Designation == ""] <- "Level 5" # Level 5 is Lower-Level than Level 4 
Traintest$Manager_Current_Designation[Traintest$Manager_Current_Designation == ""] <- "Level 4"
Traintest$Manager_Grade[is.na(Traintest$Manager_Grade)] <- 2
Traintest$Manager_Status[Traintest$Manager_Status == ""] <- "Probation"
Traintest$Manager_Gender[Traintest$Manager_Gender == ""] <- "M"

Traintest$Manager_Business<- ifelse(Traintest$Manager_Business < 0 ,Traintest$Manager_Business * (-1),Traintest$Manager_Business * (1) ) 
Traintest$Manager_Business2<- ifelse(Traintest$Manager_Business2 < 0 ,Traintest$Manager_Business2 * (-1),Traintest$Manager_Business2 * (1) ) 



# Converting Application_Reciept_Date --- > Joining_date,Applicant_BirthDate, Manager_DOJ,Manger_DoB into Dateformat 
Traintest$Application_Receipt_Date <- mdy(Traintest$Application_Receipt_Date)
Traintest$Applicant_BirthDate <- mdy(Traintest$Applicant_BirthDate)
Traintest$Manager_DOJ <- mdy(Traintest$Manager_DOJ)
Traintest$Manager_DoB <- mdy(Traintest$Manager_DoB)

Traintest<- mutate(Traintest, Manager_Age_TimeApproving = as.numeric((Traintest$Application_Receipt_Date- Traintest$Manager_DoB)/365))# Manager Age at time of Approving a particular Job
Traintest <- mutate(Traintest, Manager_Age_Joining = as.numeric((Manager_DOJ - Manager_DoB)/365))# Manager Age at the date of joining the job
Traintest <- mutate(Traintest, Applicant_Age = as.numeric((Application_Receipt_Date- Applicant_BirthDate)/365)) # Applicant Age on the date of joining 

#Filling the NA Values with median
Traintest$Applicant_Age[is.na(Traintest$Applicant_Age)] <- median(Traintest$Applicant_Age,na.rm = TRUE)
Traintest$Manager_Age_Joining[is.na(Traintest$Manager_Age_Joining)] <- median(Traintest$Manager_Age_Joining,na.rm = TRUE)
Traintest$Manager_Age_TimeApproving[is.na(Traintest$Manager_Age_TimeApproving)] <- median(Traintest$Manager_Age_TimeApproving,na.rm = TRUE)




summary(Traintest)
Traintest$Manager_Num_Application[is.na(Traintest$Manager_Num_Application)] <- median(Traintest$Manager_Num_Application,na.rm = TRUE)
Traintest$Manager_Num_Coded[is.na(Traintest$Manager_Num_Coded)] <- median(Traintest$Manager_Num_Coded,na.rm = TRUE)
Traintest$Manager_Business[is.na(Traintest$Manager_Business)] <- median(Traintest$Manager_Business,na.rm = TRUE)
Traintest$Manager_Num_Products[is.na(Traintest$Manager_Num_Products)]<- median(Traintest$Manager_Num_Products,na.rm = TRUE)
Traintest$Manager_Business2[is.na(Traintest$Manager_Business2)] <- median(Traintest$Manager_Business2,na.rm = TRUE)
Traintest$Manager_Num_Products2[is.na(Traintest$Manager_Num_Products2)]<- median(Traintest$Manager_Num_Products2,na.rm = TRUE)


Traintest <- mutate(Traintest,Advisor_Business = Manager_Business2 - Manager_Business)
Traintest <- mutate(Traintest,Advisor_Products_Sold = Manager_Num_Products2 - Manager_Num_Products)
Traintest <- mutate(Traintest,Manager_Experience = Manager_Age_TimeApproving - Manager_Age_Joining)
Traintest <- mutate(Traintest,Age_Difference = Manager_Age_TimeApproving - Applicant_Age)

# Correlations 
corrplot(cor(Traintest[,c(17:30)]),method = "number")
Traintest_1 <- Traintest[,-c(20:22,24,28,30)]
Traintest_1 <- Traintest_1[,-c(3,4,6,10,16)]


# Cleaning Data
Traintest_1$Applicant_Gender <- ifelse(Traintest_1$Applicant_Gender == "M",1,0)
Traintest_1$Manager_Gender <- ifelse(Traintest_1$Manager_Gender == "M",1,0)
Traintest_1$Manager_Status <- ifelse(Traintest_1$Manager_Status == "Confirmation",1,0)


# Divide Data into Train and Test 
traindata <- filter(Traintest_1 , Business_Sourced != 2)
testdata <- filter(Traintest_1 , Business_Sourced == 2)

traindata <- filter(traindata,Manager_Joining_Designation != "Level 7")#Remove Other and Level 7 from the traindata
traindata <- filter(traindata,Manager_Joining_Designation != "Other")#Remove Other and Level 7 from the traindata

summary(as.factor(traindata$Manager_Grade))
summary(as.factor(testdata$Manager_Grade))

traindata <- filter(traindata,Manager_Grade != 1)
traindata <- filter(traindata,Manager_Grade != 9)

traindata <- filter(traindata,Applicant_Qualification != "Associate/Fellow of Acturial Society of India")
traindata <- filter(traindata,Applicant_Qualification != "Associate/Fellow of Institute of Company Secretories of India")
traindata <- filter(traindata,Applicant_Qualification != "Associate/Fellow of Insurance Institute of India")
traindata <- filter(traindata,Applicant_Qualification != "Certified Associateship of Indian Institute of Bankers")

testdata$Applicant_Qualification[testdata$Applicant_Qualification == "Associate/Fellow of Institute of Institute of Costs and Works Accountants of India"] <- "Associate / Fellow of Institute of Chartered Accountans of India"


summary(as.factor(traindata$Applicant_Qualification))
summary(as.factor(testdata$Applicant_Qualification))

summary(as.factor(traindata$Manager_Current_Designation))
summary(as.factor(testdata$Manager_Current_Designation))

summary(as.factor(traindata$Manager_Joining_Designation))
summary(as.factor(testdata$Manager_Joining_Designation))

summary(as.factor(traindata$Office_PIN))
summary(as.factor(testdata$Office_PIN))
# Feature Engineering -- Train Data
X_office_pin <- traindata[,c(1,2)]
X_office_pin <- dcast(X_office_pin, ID ~ Office_PIN, length, value.var="ID", fill=0)
X_Applicant_Gender <- traindata[,c(1,3)]
X_Applicant_Marital_Status <- traindata[,c(1,4)]
X_Applicant_Marital_Status <- dcast(X_Applicant_Marital_Status, ID ~ Applicant_Marital_Status, length, value.var="ID", fill=0)
X_Applicant_Occupation <- traindata[,c(1,5)]
X_Applicant_Occupation <- dcast(X_Applicant_Occupation, ID ~ Applicant_Occupation, length, value.var="ID", fill=0)
X_Applicant_Qualification <- traindata[,c(1,6)]
X_Applicant_Qualification <- dcast(X_Applicant_Qualification, ID ~ Applicant_Qualification, length, value.var="ID", fill=0)
X_Manager_Joining_Designation <- traindata[,c(1,7)]
X_Manager_Joining_Designation <- dcast(X_Manager_Joining_Designation, ID ~ Manager_Joining_Designation, length, value.var="ID", fill=0)
X_Manager_Current_Designation <- traindata[,c(1,8)]
X_Manager_Current_Designation <- dcast(X_Manager_Current_Designation, ID ~ Manager_Current_Designation, length, value.var="ID", fill=0)
colnames(X_Manager_Current_Designation) <- c("ID","curr_Level 1", "curr_Level 2","curr_Level 3", "curr_Level 4", "curr_Level 5")
X_Manager_Grade <- traindata[,c(1,9)]
X_Manager_Grade <- dcast(X_Manager_Grade, ID ~ Manager_Grade, length, value.var="ID", fill=0)
X_Manager_Status <- traindata[,c(1,10)]
X_Manager_Gender <- traindata[,c(1,11)]
X_Continous <- traindata[,c(1,12:14,16:19)]

X_train_1 <- Reduce(function(x,y) merge(x,y,all=T,by="ID"),
                   list(X_Applicant_Gender,X_Applicant_Marital_Status[,-c(5)],X_Applicant_Occupation[,-c(6)],X_Applicant_Qualification[,-c(8)],
                        X_Manager_Joining_Designation[,-c(7)],X_Manager_Current_Designation[,-c(6)],X_Manager_Grade[,-c(8)],X_Manager_Status,X_Manager_Gender,
                        X_Continous))

X_target_1 <- traindata[,c(1,15)]


# Feature Engineering -- Test Data 
X_office_pin_test <- testdata[,c(1,2)]
X_office_pin_test <- dcast(testdata, ID ~ Office_PIN, length, value.var="ID", fill=0)
X_Applicant_Gender_test <- testdata[,c(1,3)]
X_Applicant_Marital_Status_test <- testdata[,c(1,4)]
X_Applicant_Marital_Status_test <- dcast(X_Applicant_Marital_Status_test, ID ~ Applicant_Marital_Status, length, value.var="ID", fill=0)
X_Applicant_Occupation_test <- testdata[,c(1,5)]
X_Applicant_Occupation_test <- dcast(X_Applicant_Occupation_test, ID ~ Applicant_Occupation, length, value.var="ID", fill=0)
X_Applicant_Qualification_test <- testdata[,c(1,6)]
X_Applicant_Qualification_test <- dcast(X_Applicant_Qualification_test, ID ~ Applicant_Qualification, length, value.var="ID", fill=0)
X_Manager_Joining_Designation_test <- testdata[,c(1,7)]
X_Manager_Joining_Designation_test <- dcast(X_Manager_Joining_Designation_test, ID ~ Manager_Joining_Designation, length, value.var="ID", fill=0)
X_Manager_Current_Designation_test <- testdata[,c(1,8)]
X_Manager_Current_Designation_test <- dcast(X_Manager_Current_Designation_test, ID ~ Manager_Current_Designation, length, value.var="ID", fill=0)
colnames(X_Manager_Current_Designation_test) <- c("ID","curr_Level 1", "curr_Level 2","curr_Level 3", "curr_Level 4", "curr_Level 5")
X_Manager_Grade_test <- testdata[,c(1,9)]
X_Manager_Grade_test <- dcast(X_Manager_Grade_test, ID ~ Manager_Grade, length, value.var="ID", fill=0)
X_Manager_Status_test <- testdata[,c(1,10)]
X_Manager_Gender_test <- testdata[,c(1,11)]
X_Continous_test <- testdata[,c(1,12:14,16:19)]



X_test_1 <- Reduce(function(x,y) merge(x,y,all=T,by="ID"),
                    list(X_Applicant_Gender_test,X_Applicant_Marital_Status_test[,-c(5)],X_Applicant_Occupation_test[,-c(6)],X_Applicant_Qualification_test[,-c(8)],
                         X_Manager_Joining_Designation_test[,-c(7)],X_Manager_Current_Designation_test[,-c(6)],X_Manager_Grade_test[,-c(8)],X_Manager_Status_test,
                         X_Manager_Gender_test,X_Continous_test))


X_train_2 <- X_train_1[,-c(1)]
X_target_2 <- X_target_1[,-c(1)]

## xgboost
seed <- 235
set.seed(seed)

# cross-validation
model_xgb_cv <- xgb.cv(data=as.matrix(X_train_2), label=as.matrix(X_target_2), objective="binary:logistic", nfold=5, nrounds=1200, eta=0.02, max_depth=5, subsample=0.6, colsample_bytree=0.85, min_child_weight=1, eval_metric="auc")
mean(model_xgb_cv$test.auc.mean) # 0.62488
mean(model_xgb_cv$train.auc.mean) # 0.8266925

# model building
model_xgb <- xgboost(data=as.matrix(X_train_2), label=as.matrix(X_target_2), objective="binary:logistic", nrounds=1200, eta=0.02, max_depth=5, subsample=0.6, colsample_bytree=0.85, min_child_weight=1, eval_metric="auc")
model_xgb$raw
# model scoring
pred <- predict(model_xgb, as.matrix(X_test_1[,-c(1)]))

# submission
submit1 <- data.frame("ID" = X_test_1$ID, "Business_Sourced" = pred)
write.csv(submit1, "submit1.csv", row.names=F)


# 60.45 on LeaderBoard 



