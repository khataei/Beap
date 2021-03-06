% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/GenerateFeatures.R
\name{GenerateFeatures}
\alias{GenerateFeatures}
\title{Generate new features from raw accelerometer data for a given time window}
\usage{
GenerateFeatures(
  raw_df,
  time_column = 1,
  x_axis_column = 2,
  y_axis_column = 3,
  z_axis_column = 4,
  window_size_sec = 1,
  overlap_sec = 0,
  frequency = 30
)
}
\arguments{
\item{raw_df}{a dataframe which has at least four columns, 'time', 'x_axis', 'y_axis', 'z_axis'}

\item{time_column}{column number of time}

\item{x_axis_column}{column number of x axis}

\item{y_axis_column}{column number of y axis}

\item{z_axis_column}{column number of z axis}

\item{window_size_sec}{windows size in second}

\item{overlap_sec}{overlap of periods in seconds}

\item{frequency}{sampling frequency}
}
\value{
new_features a dataset containing generated features
}
\description{
Generate new features from raw accelerometer data for a given time window
}
\examples{

\dontrun{
# Create a dummy dataset
sampling_freq <- 100
window_size_sec <- 1 # The model was train with this
number_of_rows <- 6000 # 60 seconds with a frequency of 100 Hz
raw_df <- seq(from= lubridate::now(),by=
                lubridate::period(num = 1/sampling_freq,units = "second"),
              length.out = number_of_rows) \%>\%  as_tibble()
x_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) \%>\%  as_data_frame()
y_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) \%>\%  as_data_frame()
z_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) \%>\%  as_data_frame()
raw_df <- bind_cols(raw_df,x_axis_df, y_axis_df, z_axis_df)

# Generate features
test_df <- Beap::GenerateFeatures(raw_df = raw_df,
                                  window_size_sec = window_size_sec,
                                  GenerateFeatures(raw_df = raw_df, window_size_sec = window_size_sec, frequency = sampling_freq)
}

}
