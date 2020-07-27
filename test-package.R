library(activityCounts)
raw_df <- activityCounts::sampleXYZ
sampling_freq <- 100
# prepare the dataset by setting proper column names
raw_df <- sampleXYZ %>%
    rename("x_axis" = 'accelerometer_X', "y_axis" = 'accelerometer_Y',
           "z_axis" = 'accelerometer_Z')
# consider a one second window
window_size_sec <- 1
# generate new features
test_df <- Beap::GenerateFeatures(raw_df = raw_df, window_size_sec = window_size_sec, frequency = sampling_freq)


library(tidyverse)
library(data.table)
library(caret)
library(ranger)

# Load the model and
model_path <- "https://storage.googleapis.com/khataei.site/Model.RData"
temp <- tempfile(fileext = ".RData")
download.file(model_path, temp)
load(temp)

test_df_tr <- test_df %>% select(-time)
test_df_tr <- test_df  %>% imputeTS::na_interpolation(option =  "linear")
predicted_df <- stats::predict(forests, test_df_tr, importance = TRUE)
predicted_df <- predicted_df[["predictions"]] %>% data.frame()

sum(is.na(test_df_tr$cor_xy))
