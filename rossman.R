library(randomForest)
train <- read.csv('train.csv',colClasses=c("factor","factor","Date","integer","integer","factor","factor","factor","factor"))
train[,6] <- train[,6] == 1 #converting the open column from numerical to logical
train[,7] <- train[,7] == 1 #converting the Promo column from numerical to logical
train[,9] <- train[,9] == 1 #converting SchoolHoliday column from numerical to logical
summary(train)

#Reading store data
store <- read.csv('store.csv',colClasses=c("factor","factor","factor","integer","integer","integer","factor","integer","integer","character"))
store[,7] <- store[,7] == 1 #converting the Promo2 column from numerical to logical
summary(store)

store[2,] #PromoInterval has various months in it.

test <- read.csv('test.csv',colClasses=c("numeric","factor","factor","Date","integer","integer","factor","factor"))
test[,5] <- test[,5] == 1 #converting the numerical values in Open column to logical
test[,6] <- test[,6] == 1 #converting the numerical values in Promo column to logical
test[,8] <- test[,8] == 1 #converting the numerical values in StateHoliday column to logical
summary(test)
head(test)

test <- test[2:8] #removing the first column as it is similar to Id and is redundant

summary(train$Sales[!train$Open]) #Summary of the shops that are closed 

train <- train[train$Open,] #removing the data of closed stores

#Dates are seperated so that they can used as numerical values
train$Day <- as.numeric(strftime(train$Date, format="%d"))
train$Year <- as.numeric(strftime(train$Date, format="%y"))
train$Month <- as.numeric(strftime(train$Date, format="%m"))
train$Week <- as.numeric(strftime(train$Date, format="%W"))
train <- train[c(1,4,7:13,2)]
head(train)

#Collecting the IDs of the store in a seperate variable so that we can use only the stores for
#which we have to predict for, which are available in the test store
stores_to_test <- as.numeric(as.character(unique(test$Store)))

#removing the stores from training set those are not present in test dataset
nrow(train)
train <- train[train$Store %in% stores_to_test,]
nrow(train)

#removing the missing values in test data
test[is.na(test$Open),]
#store 622 has nA values except for Sundays, we interpret that the store will be open as the 
#store is closed on Sunday but there is an active promo going on the first four days.
test[test$Store == 622 & test$Date > "2015-09-05" & test$DayOfWeek == 7,]
test[is.na(test$Open),]$Open <- T

#EDA
summary(train$Sales)
sd(train$Sales)
boxplot(train$Sales) #Outliers are the sales above 20000
hist(train$Sales,xlab="Sales")

summary(train[train$Sales > 20000,]) #checking the outliers
#investigating each variable against sales 
#Promotions with Sales
t.test(train[train$Promo,]$Sales,train[!train$Promo,]$Sales)
#promotions highly affect Sales 

#StateHoliday with Sales
t.test(train[train$StateHoliday != 0,]$Sales,train[train$StateHoliday == 0,]$Sales)
#SchoolHoliday with Sales
t.test(train[train$SchoolHoliday,]$Sales,train[!train$SchoolHoliday,]$Sales)
#SchoolHolidays do not affect Sales but StateHolidays of all types do

#Baseline Prediction
#the baseline prediction would be that the store has 0 sales when closed and we could 
#assign the open days having mean of all the sales.
store_one <- train[train$Store == 1,] #Using store no. 1
mean(store_one$Sales) #Mean of the sales for store no.1
store_one$Result <- mean(store_one$Sales)
store_one$Error <- store_one$Result - store_one$Sales
sqrt(mean((store_one$Sales-store_one$Result)^2)) #root mean sqaured error.

#We check if the median can be used for baseline prediction as well
store_one$Result <- median(store_one$Sales) 
sqrt(mean((store_one$Sales-store_one$Result)^2))
#We continue with mean as it has less root mean squared error than median

#For all the stores:
inaccuracies <- rep(0,length(stores_to_test))
sales_means <- aggregate(train$Sales,list(train$Store),mean)
i <- 1
for ( k in stores_to_test) {
  inaccuracies[i] <- sqrt(mean((train[train$Store == k,]$Sales - sales_means[sales_means$Group.1 == k,2])^2))
  i <- i + 1
}
summary(inaccuracies)
sd(inaccuracies)
hist(inaccuracies)

#Analyzing the high errors
high_errors <- cbind(as.numeric(as.character(stores_to_test[inaccuracies > 3500])),inaccuracies[inaccuracies > 3500])
high_errors
#we calculate the root mean square deviation for all the stores
train$Results <- apply(train[1],1,function(x){sales_means[sales_means$Group.1 == x,2]})
sqrt(mean((train$Sales-train$Results)^2))

#Linear Regression

linear_reg_function <- function(selected_store) {
  store_one <- train[train$Store == selected_store,]  # select a store
  idx_shuffle <- sample(nrow(store_one))  # shuffle the data
  store_one$Result <- 0
  y <- nrow(store_one)
  #we use 10 fold cross validation 
  for (j in 1:10) {    
    idx <- floor(1+0.1*(j-1)*y):(0.1*j*y)  #select 10% data rows
    test_set <- store_one[idx_shuffle[idx],]  #the set for testing
    train_set <- store_one[idx_shuffle[-idx],]  #the set for training
    lr_m <- lm(Sales ~ Promo + SchoolHoliday + DayOfWeek + as.factor(Year) + as.factor(Month)
               + as.factor(Day) + as.factor(Week), train_set)  # The model for linear regression
    store_one[idx_shuffle[idx],]$Result <- predict(lr_m,test_set) 
    #using the model to use on test set and predict results
  }
  #the prediction for 1st June 2013 is providing high values which is affecting the root mean square value 
  print(paste("Prediction for 13/6/1: ", store_one[store_one$Year == 13 & store_one$Month == 6 & store_one$Day == 1,]$Result))
  
  #for this reason we set the value of store sales to the mean on July 1st 2013
  store_one[store_one$Year == 13 & store_one$Month == 6 & store_one$Day == 1,]$Result <- mean(store_one$Result)
  
  print(paste("Training error: ", summary.lm(lr_m)[6]))  #Training Error
  
  sqrt(mean((store_one$Sales-store_one$Result)^2))#Root mean square error
}
paste("Root Mean Square Error: ", store_function(1)) 
#The root mean square value for linear regression is better than baseline prediction for store 1.
#calling the linear regression function for all the stores
inaccuracies <- rep(0,length(stores_to_test))
i <- 0
for ( j in stores_to_test ) {
  inaccuracies[i] <- linear_reg_function(j)
  i <- i + 1
}
inaccuracies
mean(inaccuracies)
#the predict model using this linear regression fails as the Week factor does not match in test_set and train_set in few iterations
#We solve this by manually changing the variables.

table1 <- train[c(1,2)]
table1 <- cbind(table1,model.matrix(Sales ~ Promo + StateHoliday + SchoolHoliday + DayOfWeek + as.factor(Year) 
                            + as.factor(Month) + as.factor(Day) + as.factor(Week), data = train))


linear_reg_function2 <- function(selected_store) {
  store_one <- table1[table1$Store == selected_store,2:ncol(table1)]  # select a store
  idx_shuffle <- sample(nrow(store_one))  # shuffle the data
  store_one$Result <- 0
  y <- nrow(store_one)
  #we use 10 fold cross validation 
  for (j in 1:10) {    
    idx <- floor(1+0.1*(j-1)*y):(0.1*j*y)  #select 10% data rows
    test_set <- store_one[idx_shuffle[idx],]  #the set for testing
    train_set <- store_one[idx_shuffle[-idx],1:(ncol(store_one)-1)]  #the set for training
    lr_m <- lm(Sales ~ ., train_set)  # The model for linear regression
    store_one[idx_shuffle[idx],]$Result <- predict(lr_m,test_set) 
    #using the model to use on test set and predict results
  }
  store_one[store_one$Result == max(store_one$Result),]$Result <- mean(store_one$Result)
  
  sqrt(mean((store_one$Sales-store_one$Result)^2))#Root mean square error
}
inaccuracies <- rep(0,length(stores_to_test))
i <- 0
for ( j in stores_to_test ) {
  inaccuracies[i] <- linear_reg_function2(j)
  i <- i + 1
}
mean(inaccuracies)


#We try random forest to reduce the error
random_forest_model <- function(selected_store,category_of_model,...) {
  store_one <- train[train$Store == selected_store,]
  store_one$Promo <- as.numeric(store_one$Promo)
  store_one$StateHoliday <- as.numeric(store_one$StateHoliday)
  store_one$SchoolHoliday <- as.numeric(store_one$SchoolHoliday)
  store_one$Week <- as.numeric(store_one$Week)
  store_one$DayOfWeek <- as.numeric(store_one$DayOfWeek)
  idx_shuffle <- sample(nrow(store_one))
  store_one$Result <- 0
  k <- nrow(store_one)
  for (j in 1:10) {
    idx <- floor(1+0.1*(j-1)*k):(0.1*j*k)
    test_set <- store_one[idx_shuffle[idx],] #divide the data into test set
    train_set <- store_one[idx_shuffle[-idx],(2:(ncol(store_one)-1))] #divide the data into train set
    mdl <- category_of_model(Sales ~ ., train_set, ...)
    store_one[idx_shuffle[idx],]$Result <- predict(mdl,test_set) #predicting the sales and saving them in the result variable.
  }
  
  sqrt(mean((store_one$Sales-store_one$Result)^2)) #calculating the root mean square error for the prediction
}


#calling the random forestfunction for all the stores in the dataset.
inaccuracies <- rep(0,length(stores_to_test))
i <- 0
for ( j in stores_to_test ) {
  inaccuracies[i] <- random_forest_model(j,randomForest,ntree=200)
  i <- i + 1
}
mean(inaccuracies)







