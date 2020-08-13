# """
# For testing the package
#
# Javad Khataei
# j.khataee@gmail.com
# """


library(activityCounts)
library(tidyverse)
library(data.table)
library(caret)
library(ranger)


# Load the model
model_path <- "https://storage.googleapis.com/khataei.site/Model.RData"
temp <- tempfile(fileext = ".RData")
download.file(model_path, temp)
load(temp)



# Read sample data produced by "Accelerometer Analyzer" app
raw_df <- fread("sample-accel-data.csv")
sampling_freq <- 50 # This was set in the app
window_size_sec <- 1 # The model was train with this

# Create features
test_df <- Beap::GenerateFeatures(raw_df = raw_df,
                                  window_size_sec = window_size_sec,
                                  frequency = sampling_freq)

# Impute null values as the model cannot work if there's any null value
test_df_tr <- test_df  %>% imputeTS::na_interpolation(option =  "linear")


predicted_df <- stats::predict(forests, test_df_tr)
predicted_df <- predicted_df[["predictions"]] %>% data.frame()



# Optional: Create time column for the results
start_time <- raw_df[1,1] %>% as.character() %>% lubridate::as_datetime()
time_df <- seq(from=start_time,by=
                   lubridate::period(num = window_size_sec,units = "second"),
               length.out = nrow(predicted_df)) %>%  as_tibble()

# Optional: Bind time to the results
predicted_df <- bind_cols(time_df, predicted_df)
View(predicted_df)

# ================================================#
# An example for function header

# Create a dummy dataset
sampling_freq <- 100
window_size_sec <- 1 # The model was train with this
number_of_rows <- 6000 # 60 seconds with a frequency of 100 Hz
raw_df <- seq(from= lubridate::now(),by=
                  lubridate::period(num = 1/ sampling_freq,units = "second"),
              length.out = number_of_rows) %>%  as_tibble()
x_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
y_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
z_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
raw_df <- bind_cols(raw_df,x_axis_df, y_axis_df, z_axis_df)

# Generate features
test_df <- Beap::GenerateFeatures(raw_df = raw_df,
                                  window_size_sec = window_size_sec,
                                  frequency = sampling_freq)
