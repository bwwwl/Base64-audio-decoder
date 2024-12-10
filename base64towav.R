# For macOS Users:
# a. Install Homebrew (if not already installed):
#   
# Homebrew is a popular package manager for macOS. If you haven't installed it yet, open the Terminal application and run:
# 
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# b. Install ffmpeg using Homebrew:
# 
# Once Homebrew is installed, run the following command in the Terminal:
# 
# brew install ffmpeg

# c. Verify ffmpeg Installation:
# 
# After installation, confirm that ffmpeg is installed correctly by running:
# 
# ffmpeg -version
# You should see version information for ffmpeg if it's installed properly.

library(base64enc)
library(tools)

# Define input and output directories
input_dir <- "/Users/brian/Desktop/bcbl/TEPRA/data/temporal_variability/1csv"
output_dir <- "/Users/brian/Desktop/bcbl/TEPRA/data/temporal_variability/3wav"

# Ensure the output directory exists
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  message("Created output directory: ", output_dir)
} else {
  message("Output directory exists: ", output_dir)
}

# Get all CSV files
csv_files <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE)
message("Found CSV files: ", paste(csv_files, collapse = ", "))

if (length(csv_files) == 0) {
  stop("No CSV files found in the input directory.")
}

# Specify the full path to ffmpeg
ffmpeg_path <- "/opt/homebrew/bin/ffmpeg"  # macOS/Linux example
# Uncomment and set the correct path for Windows
# ffmpeg_path <- "C:/ffmpeg/bin/ffmpeg.exe"

# Check if ffmpeg exists at the specified path
if (!file.exists(ffmpeg_path)) {
  stop("ffmpeg not found at the specified path: ", ffmpeg_path)
}

for (csv_path in csv_files) {
  message("Processing file: ", csv_path)
  
  # Read CSV
  df <- read.csv(csv_path, stringsAsFactors = FALSE)
  message("Read CSV with dimensions: ", paste(dim(df), collapse = " x "))
  
  # Check if the CSV has enough rows/columns
  if (nrow(df) < 27 || ncol(df) < 12) {
    warning("Not enough rows/columns for indexing: ", csv_path)
    next
  }
  
  # Extract base name
  csv_basename <- file_path_sans_ext(basename(csv_path))
  
  # Extract the Base64 data (rows 11–15, 22–26 in column 12) (change the location of the base64 data here)
  base64_values_part1 <- df[11:15, 12]
  base64_values_part2 <- df[22:26, 12]
  
  base64_values <- c(base64_values_part1, base64_values_part2)
  
  # Check extracted values
  message("Base64 values (span): ", paste(base64_values_part1, collapse = ", "))
  message("Base64 values (eng): ", paste(base64_values_part2, collapse = ", "))
  
  # Process each extracted Base64 string
  for (i in seq_along(base64_values)) {
    base64_string <- base64_values[i]
    
    if (is.na(base64_string) || !nzchar(base64_string)) {
      warning("Empty or invalid Base64 string at index ", i, " in file ", csv_path)
      next
    }
    
    # Decode Base64 to binary (webm)
    audio_data <- base64decode(base64_string)
    
    # Determine filenames
    if (i <= 5) {
      # First 5 files: span
      webm_filename <- paste0(csv_basename, "_span_", i, ".webm")
      wav_filename <- paste0(csv_basename, "_span_", i, ".wav")
    } else {
      # Next 5 files: eng
      index_eng <- i - 5
      webm_filename <- paste0(csv_basename, "_eng_", index_eng, ".webm")
      wav_filename <- paste0(csv_basename, "_eng_", index_eng, ".wav")
    }
    
    webm_path <- file.path(output_dir, webm_filename)
    wav_path <- file.path(output_dir, wav_filename)
    
    # Write the webm file
    writeBin(audio_data, webm_path)
    message("Wrote WebM file: ", webm_path)
    
    # Convert WebM to WAV using ffmpeg
    ffmpeg_cmd <- paste(shQuote(ffmpeg_path), "-y -i", shQuote(webm_path), "-acodec pcm_s16le -ar 44100", shQuote(wav_path))
    message("Running ffmpeg: ", ffmpeg_cmd)
    
    # Execute the ffmpeg command and capture output
    ffmpeg_output <- system(ffmpeg_cmd, intern = TRUE)
    
    # Print ffmpeg output for debugging
    if (length(ffmpeg_output) > 0) {
      message("ffmpeg output:\n", paste(ffmpeg_output, collapse = "\n"))
    }
    
    # Check if wav file was created
    if (!file.exists(wav_path)) {
      warning("WAV file was not created for: ", webm_path)
    } else {
      message("Converted to WAV: ", wav_path)
      # Remove the intermediate webm file if conversion is successful
      file.remove(webm_path)
      message("Removed intermediate WebM file: ", webm_path)
    }
  }
  
  message("Finished processing file: ", csv_path)
}

message("All files processed. WAV files are now available in: ", output_dir)
