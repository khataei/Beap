#' Generate new features from raw accelerometer data for a given time window
#'
#' @param raw_df a dataframe which has at least four columns, 'time', 'x_axis', 'y_axis', 'z_axis'
#' @param window_size_sec windows size in second
#' @param frequency sampling frequency
#' @param time_column column number of time
#' @param x_axis_column column number of x axis
#' @param y_axis_column column number of y axis
#' @param z_axis_column column number of z axis
#' @param overlap_sec overlap of periods in seconds
#'
#' @return new_features a dataset containing generated features
#' @export
#'
#' @import lubridate
#' @import activityCounts
#' @import magrittr
#' @import zoo
#' @import e1071
#' @import progress
#' @importFrom rlang .data
#' @importFrom stats cor sd setNames
#' @import dplyr
#'
#' @examples
#'
#' \dontrun{
#' # Create a dummy dataset
#' sampling_freq <- 100
#' window_size_sec <- 1 # The model was train with this
#' number_of_rows <- 6000 # 60 seconds with a frequency of 100 Hz
#' raw_df <- seq(from= lubridate::now(),by=
#'                 lubridate::period(num = 1/sampling_freq,units = "second"),
#'               length.out = number_of_rows) %>%  as_tibble()
#' x_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
#' y_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
#' z_axis_df <- runif(n=number_of_rows, min=1e-12, max=.9999999999) %>%  as_data_frame()
#' raw_df <- bind_cols(raw_df,x_axis_df, y_axis_df, z_axis_df)
#'
#' # Generate features
#' test_df <- Beap::GenerateFeatures(raw_df = raw_df,
#'                                   window_size_sec = window_size_sec,
#'                                   GenerateFeatures(raw_df = raw_df, window_size_sec = window_size_sec, frequency = sampling_freq)
#' }
#'
GenerateFeatures <-
  function(raw_df,
           time_column = 1,
           x_axis_column = 2,
           y_axis_column = 3,
           z_axis_column = 4,
           window_size_sec = 1,
           overlap_sec = 0,
           frequency = 30) {
    # ------------------------- Variable dictionary -------------------------- #
    # window_size_sec: windows size in second
    # frequency: dataset frequency
    # window_size: number of readings that each window contains and the features are calucated for
    # ------------------------------------------------------------------------ #



    window_size <- round(window_size_sec * frequency, digits = 0)
    overlap <- round(overlap_sec * frequency, digits =  0)
    distance <- window_size - overlap


    message(paste0("The window size is set to: ", window_size, " observations"))

    message(paste0("overlap size is set to ", overlap, " observations"))

    # create empty dataframe to store all the new features
    new_features <- NULL


    # To show the progress
    pb <- progress_bar$new(
      format = "Creating features [:bar] :current/:total, time elapsed :elapsedfull",
      total = 18,
      clear = F,
      width = 70
    )
    pb$message(" --- Generating New Features ---")
    pb$tick(0)

    # The following functions work on the 'x_axis', 'y_axis', 'z_axis' columns
    raw_df  %<>% dplyr::select(c(time_column, x_axis_column, y_axis_column, z_axis_column))
    colnames(raw_df) <- c("time", "x_axis", "y_axis", "z_axis")
    message(
      paste0(
        "Features will be generate based on columns ",
        x_axis_column,
        ", ",
        y_axis_column,
        ", ",
        z_axis_column,
        " as x, y and z axes."
      )
    )


    # 0----------------- First ----------------- #
    # From each period that the features are calculated for
    # Select the first row of raw data
    base_df <- raw_df %>%
      dplyr::select('time', 'x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(width = window_size,
                     by = distance,
                     FUN = dplyr::first) %>%
      as.data.frame()

    new_features %<>% dplyr::bind_cols(base_df)



    # 1----------------- Sum ----------------- #
    sum_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(width = window_size,
                     by = distance,
                     FUN = sum) %>%
      as.data.frame() %>%
      rename("sum_x" = 'x_axis',
             "sum_y" = 'y_axis',
             "sum_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(sum_features)
    pb$tick()
    pb$message("Sum features are created")



    # 2----------------- Signal Power ----------------- #
    # instantaneous power
    snp_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          sum(x ^ 2)
      ) %>%
      as.data.frame() %>%
      rename("snp_x" = 'x_axis',
             "snp_y" = 'y_axis',
             "snp_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(snp_features)
    pb$tick()
    pb$message("power features are created")



    # 3----------------- Mean -----------------
    mean_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(width = window_size,
                     by = distance,
                     FUN = mean) %>%
      as.data.frame() %>%
      rename("mean_x" = 'x_axis',
             "mean_y" = 'y_axis',
             "mean_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(mean_features)
    pb$tick()
    pb$message("Mean features are created")



    # 4--------------- Standard deviation-------------
    sd_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(width = window_size,
                     by = distance,
                     FUN = sd) %>%
      as.data.frame() %>%
      rename("sd_x" = 'x_axis',
             "sd_y" = 'y_axis',
             "sd_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(sd_features)
    pb$tick()
    pb$message("Standard deviation features are created")



    # ------------------- CV --------------------
    # The coefficient of variation (CV)  or relative standard deviation
    # The ratio of the standard deviation to the mean.
    # The higher the coefficient of variation, the greater the level of dispersion around the mean.
    cv_feature <- sd_features / mean_features
    cv_feature %<>% rename("cv_x" = 'sd_x',
                           "cv_y" = 'sd_y',
                           "cv_z" = 'sd_z')

    new_features %<>% dplyr::bind_cols(cv_feature)
    pb$tick()
    pb$message("Coefficient of variation features are created")



    # 6----------------- Peak-to-peak amplitude--------------
    # Peak amplitude is the maximum value minus minimum value of signal at each window
    amp_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(a)
          max(a) - min(a)
      ) %>%
      as.data.frame() %>%
      rename("amp_x" = 'x_axis',
             "amp_y" = 'y_axis',
             "amp_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(amp_features)
    pb$tick()
    pb$message("Peak-to-peak amplitude features are created")



    # 7----------------- IQR --------------
    iqr_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN =  function(a)
          stats::IQR(a, na.rm = T)
      ) %>%
      as.data.frame() %>%
      rename("iqr_x" = 'x_axis',
             "iqr_y" = 'y_axis',
             "iqr_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(iqr_features)
    pb$tick()
    pb$message("IQR features are created")



    # 8-------------- Correlation between accelerometer axes-------

    # Between x and y
    cor_xy_feature <- raw_df %>%
      dplyr::select('x_axis', 'y_axis') %>%
      rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          stats::cor(x[, 1], x[, 2]),
        by.column = FALSE # If TRUE, FUN is applied to each column separately
      ) %>%
      as.data.frame() %>%
      setNames("cor_xy")

    # Between x and z
    cor_xz_feature <- raw_df %>%
      dplyr::select('x_axis', 'z_axis') %>%
      rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          stats::cor(x[, 1], x[, 2]),
        by.column = FALSE # If TRUE, FUN is applied to each column separately
      ) %>%
      as.data.frame() %>%
      setNames("cor_xz")

    # Between y and z
    cor_yz_feature <- raw_df %>%
      dplyr::select('y_axis', 'z_axis') %>%
      rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          cor(x[, 1], x[, 2]),
        by.column = FALSE # If TRUE, FUN is applied to each column separately
      ) %>%
      as.data.frame() %>%
      setNames("cor_yz")

    new_features %<>% dplyr::bind_cols(cor_xy_feature, cor_xz_feature, cor_yz_feature)
    pb$tick()
    pb$message("Correlation features are created")





    # 9----------------- Autocorrelation --------------
    acf_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          stats::acf(
            x,
            lag.max = 1,
            plot = F,
            na.action = stats::na.pass
          )[["acf"]][2]
      ) %>%
      as.data.frame() %>%
      rename("acf_x" = 'x_axis',
             "acf_y" = 'y_axis',
             "acf_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(acf_features)
    pb$tick()
    pb$message("Autocorrelation features are created")



    # 10----------------- Skewness --------------
    # measure of asymmetry of the singal probabilty distribution
    skw_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          e1071::skewness(x, na.rm = T)
      ) %>%
      as.data.frame() %>%
      rename("skw_x" = 'x_axis',
             "skw_y" = 'y_axis',
             "skw_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(skw_features)
    pb$tick()
    pb$message("Skewness features are created")

    # 11----------------- Kurtosis -----------------
    # degree of the peakedness of the signal probability distribution
    krt_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          e1071::kurtosis(x, na.rm = T)
      ) %>%
      as.data.frame() %>%
      rename("krt_x" = 'x_axis',
             "krt_y" = 'y_axis',
             "krt_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(krt_features)
    pb$tick()
    pb$message("Kurtosis features are created")




    # 12-------------------- Sum Log-energy ----------------

    sle_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x)
          sum(log(x ^ 2 + 1))
      ) %>%
      as.data.frame() %>%
      rename("sle_x" = 'x_axis',
             "sle_y" = 'y_axis',
             "sle_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(sle_features)
    pb$tick()
    pb$message("Sum Log-energy features are created")




    # 13-------------------- Peak intensity ----------------
    # "number of the signal peak apperances within a certain period of time"
    # round the data to three digits and see how many maximum values there are

    pin_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x) {
          x <- round(x = x, digits = 3)
          max_of_window <- max(x)
          which(x == max_of_window) %>%
            length() %>%
            return()
        }
      ) %>%
      as.data.frame() %>%
      rename("pin_x" = 'x_axis',
             "pin_y" = 'y_axis',
             "pin_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(pin_features)
    pb$tick()
    pb$message("Peak intensity features are created")



    # 14------------------ Zero Crossing --------------
    # "zero crossings is the number of the times that the signal crosses its median."
    # we calculate the mean and subtract it from all the readings to create x_centralized
    # multiple each x_centralized row with the next one and if the result is negative, it has crossed

    zcr_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x) {
          x_centralized <- x - stats::median(x = x, na.rm = T)
          zcr <- 0
          for (i in 1:(window_size - 1)) {
            if (!is.na(x_centralized[i] * x_centralized[i + 1])) {
              if (x_centralized[i] * x_centralized[i + 1] < 0) {
                # This is just good enough
                zcr <- zcr + 1
              }
            }
          }
          return(zcr)
        }
      ) %>%
      as.data.frame() %>%
      rename("zcr_x" = 'x_axis',
             "zcr_y" = 'y_axis',
             "zcr_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(zcr_features)
    pb$tick()
    pb$message("Zero Crossing features are created")


    # 15------------------ Dominant frequency--------------

    dfr_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x) {
          FT <- stats::fft(x)
          return(max(Re(FT ^ 2)))
        }
      ) %>%
      as.data.frame() %>%
      rename("dfr_x" = 'x_axis',
             "dfr_y" = 'y_axis',
             "dfr_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(dfr_features)
    pb$tick()
    pb$message("Dominant frequency features are created")


    # 16------------------ Amplitude of dominant frequency--------------

    adf_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x) {
          FT <- stats::fft(x)
          idx <- which.max(Re(FT ^ 2))
          return(Re(FT[idx]))
        }
      ) %>%
      as.data.frame() %>%
      rename("adf_x" = 'x_axis',
             "adf_y" = 'y_axis',
             "adf_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(adf_features)
    pb$tick()
    pb$message("Amplitude of dominant frequency- features are created")





    # 17-------------------- Entropy ----------------
    # https://en.wikipedia.org/wiki/Entropy#Information_theory
    # https://stackoverflow.com/questions/27254550/calculating-entropy

    ent_features <- raw_df %>%
      dplyr::select('x_axis', 'y_axis', 'z_axis') %>%
      zoo::rollapply(
        width = window_size,
        by = distance,
        FUN = function(x) {
          probabilities <- prop.table(table(x))
          return(-sum(probabilities * log2(probabilities)))
          # Note:
          # Using the library entropy does not give us the same results
          # return(entropy::entropy.empirical(x, unit = "log2"))
        }
      ) %>%
      as.data.frame() %>%
      rename("ent_x" = 'x_axis',
             "ent_y" = 'y_axis',
             "ent_z" = 'z_axis')

    new_features %<>% dplyr::bind_cols(ent_features)
    pb$tick()
    pb$message("Entropy features are created")




    # 18-------------------- magnitudes ----------------------
    # 1. For each row we calculate the magnitude and take their average in each window
    # 2. Also we calculte magnitude minus g, 0.9808
    # 3. the mean features of each window for x y, and z was calculated before,
    #    here we calculate their magnitudes
    # 4. ntile for the magnitude calculated in the first step

    # 1.
    vec_mag <-
      sqrt(raw_df$x_axis ^ 2 + raw_df$y_axis ^ 2 + raw_df$z_axis ^ 2) %>%
      as.data.frame()

    vec_mag_features <- vec_mag %>%
      zoo::rollapply(width = window_size,
                     by = distance,
                     FUN = mean) %>%
      as.data.frame()
    colnames(vec_mag_features) <- "vec_mag"

    # commented out due to multicollinearity with vec_mag
    # Also line 559(new_features %<>% dplyr::bind_cols(vec_mag_features, vec_mag_g_features, vec_mag_mean_feature)) is edited
    # # 2.
    # vec_mag_g_features <- vec_mag_features - 0.9808
    # colnames(vec_mag_g_features) <- "vec_mag-g"


    # 3.
    vec_mag_mean_feature <-
      sqrt(mean_features$mean_x ^ 2 + mean_features$mean_y ^ 2 + mean_features$mean_z ^
             2) %>%
      as.data.frame()
    colnames(vec_mag_mean_feature) <- "vec_mag_mean"
    new_features %<>% dplyr::bind_cols(vec_mag_features, vec_mag_mean_feature)


    # 4.
    new_features$ntile <- dplyr::ntile(new_features$vec_mag, 5)



    pb$message("vector magnitude features are created")
    pb$tick()



    message("New features are ready to use")
    return(new_features)
  }
