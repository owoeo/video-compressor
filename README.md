# Video Compressor App

A macOS application built with Flutter that allows users to compress video files using FFmpeg.

## Features

- Video file selection using system file picker (via image_picker)
- Video file compression using FFmpeg
- Progress tracking during compression with real-time updates
- Configurable compression parameters:
  - CRF (Constant Rate Factor) - 0-51, where lower values mean higher quality
  - Preset - Controls encoding speed to compression ratio
  - Video bitrate - Target bitrate for video encoding
  - Audio bitrate - Target bitrate for audio encoding
- File size comparison between input and output files

## Prerequisites

- Flutter SDK
- macOS development environment

## Installation

1. Clone or download this repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run -d macos` to launch the application

## Usage

1. Click "Select Video" to choose a video file for compression using the system file picker
2. Adjust compression parameters as needed:
   - **CRF**: 0 (lossless) to 51 (worst quality), default is 23
   - **Preset**: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
   - **Video Bitrate**: e.g., 1000k, 2M (optional)
   - **Audio Bitrate**: e.g., 128k, 256k
3. Click "Compress Video" to start the compression process
4. Progress will be displayed during compression with percentage
5. Once complete, the compressed video will be saved in your Downloads directory

## How It Works

The application uses the `ffmpeg_kit_flutter_new` package to execute FFmpeg commands for video compression. The core command used is:

```
ffmpeg -i [input] -c:v libx264 -crf [value] -preset [value] -c:a aac -b:a [value] [output]
```

## Parameters Explained

- **CRF (Constant Rate Factor)**: Controls quality where:
  - 0 = lossless compression
  - 18-28 = visually transparent to good quality
  - 23 = default value
  - 51 = worst quality

- **Preset**: Controls the speed of compression:
  - ultrafast = fastest, largest file size
  - medium = default balance
  - veryslow = slowest, smallest file size

- **Video Bitrate**: Alternative to CRF for controlling quality:
  - 500k = low quality
  - 1000k = medium quality
  - 2M = high quality

- **Audio Bitrate**: Controls audio quality:
  - 128k = standard quality
  - 256k = high quality

## Troubleshooting

If you encounter any issues:

1. Make sure you have proper permissions to read the input file and write to the output directory
2. Ensure the input video file is a valid format supported by FFmpeg
3. Check that you have enough disk space for the output file
4. If the app crashes during compression, try adjusting the compression parameters to be less intensive

## Technical Implementation Details

### Progress Tracking

The application implements two levels of progress tracking:

1. **Time-based tracking**: When video duration is available, it calculates progress based on processed time vs. total duration
2. **Frame-based tracking**: When duration is not available, it displays the current frame number being processed

### Video Duration Detection

The app uses FFprobe (from the ffmpeg_kit_flutter_new package) to accurately determine video duration, with a fallback to FFmpeg if FFprobe fails.

### Asynchronous Processing

Video compression is performed asynchronously using `FFmpegKit.executeAsync` to ensure the UI remains responsive and progress updates are smooth.

## Future Improvements

1. Add support for more compression parameters
2. Implement compression cancellation functionality
3. Add preview functionality for compressed videos
4. Allow users to select the output directory
5. Add support for batch processing multiple videos