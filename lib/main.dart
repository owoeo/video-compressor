import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Compressor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VideoCompressorPage(),
    );
  }
}

class VideoCompressorPage extends StatefulWidget {
  const VideoCompressorPage({super.key});

  @override
  State<VideoCompressorPage> createState() => _VideoCompressorPageState();
}

class _VideoCompressorPageState extends State<VideoCompressorPage> {
  List<String> _inputVideoPaths = []; // 更改为列表以支持多文件
  String? _outputVideoPath;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  String _status = 'Select videos to compress';
  double _selectedCrf = 23.0; // 将String类型改为double类型
  String? _selectedPreset = 'medium';
  String? _selectedVideoBitrate;
  String? _selectedAudioBitrate = '128k';
  String? _selectedResolution;
  int? _videoDuration;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  Future<void> _pickVideo() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isEmpty) {
      return;
    }

    setState(() {
      _inputVideoPaths = List.from(
        pickedFiles
            .where((element) => element.path.endsWith('.mp4'))
            .map((element) => element.path)
            .toList(),
      );
      _status =
          'Selected ${_inputVideoPaths.length} videos. Tap "Select Videos" again to add more, or "Compress Videos" to start.';
    });
  }

  Future<int?> _getVideoDuration(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final information = await session.getMediaInformation();
        if (information != null) {
          final durationString = information.getDuration();
          if (durationString != null) {
            final durationInSeconds = double.tryParse(durationString);
            if (durationInSeconds != null) {
              // Print for debugging
              if (kDebugMode) {
                print('Video duration: $durationInSeconds seconds');
              }
              return (durationInSeconds * 1000)
                  .toInt(); // Convert to milliseconds
            }
          }
        }
      } else {
        final failStackTrace = await session.getFailStackTrace();
        if (kDebugMode) {
          print('FFprobe failed to get media information: $failStackTrace');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting video duration with FFprobe: $e');
      }
    }

    // Fallback to FFmpeg method
    try {
      final session = await FFmpegKit.execute(
        '-v quiet -show_entries format=duration -of csv=p=0 "$videoPath"',
      );
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        if (output != null) {
          final durationInSeconds = double.tryParse(output.trim());
          if (durationInSeconds != null) {
            if (kDebugMode) {
              print(
                'Video duration (fallback method): $durationInSeconds seconds',
              );
            }
            return (durationInSeconds * 1000)
                .toInt(); // Convert to milliseconds
          }
        }
      } else {
        final failStackTrace = await session.getFailStackTrace();
        if (kDebugMode) {
          print('FFmpeg fallback method failed: $failStackTrace');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting video duration with FFmpeg fallback: $e');
      }
    }

    return null;
  }

  Future<void> _compressVideo() async {
    if (_inputVideoPaths.isEmpty) {
      setState(() {
        _status = 'Please select videos first';
      });
      return;
    }

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
      _status = 'Compressing videos...';
    });

    // 逐个压缩所有选定的视频
    for (int i = 0; i < _inputVideoPaths.length; i++) {
      final String inputVideoPath = _inputVideoPaths[i];

      // Check if input file exists
      final inputFile = File(inputVideoPath);
      if (!await inputFile.exists()) {
        setState(() {
          _status = 'Input video file does not exist: $inputVideoPath';
        });
        continue;
      }

      // Get video duration for progress tracking
      _videoDuration = await _getVideoDuration(inputVideoPath);
      if (_videoDuration == null) {
        setState(() {
          _status =
              'Warning: Could not determine video duration. Progress tracking may be inaccurate.';
        });
      } else {
        if (kDebugMode) {
          print('Video duration obtained: $_videoDuration ms');
        }
      }

      // Generate output path
      final outputDirFolder = await getDownloadsDirectory();
      final outputDir = outputDirFolder?.path;
      if (outputDirFolder == null) {
        setState(() {
          _status = 'Error: Downloads directory not found';
        });
        return;
      }

      final fileName = inputVideoPath.split('/').last;
      final nameWithoutExtension = fileName.split('.').first;
      _outputVideoPath = '$outputDir/${nameWithoutExtension}_compressed.mp4';

      setState(() {
        _status =
            'Compressing video ${i + 1} of ${_inputVideoPaths.length}: $fileName';
      });

      try {
        // Build FFmpeg command
        final List<String> commandParts = [
          '-i',
          '"$inputVideoPath"',
          '-c:v',
          'libx264',
        ];

        // Add video scaling if provided
        final String widthText = _widthController.text.trim();
        final String heightText = _heightController.text.trim();

        // 如果提供了宽度或高度，则添加缩放参数
        if (widthText.isNotEmpty || heightText.isNotEmpty) {
          String scaleParam = 'scale=';

          if (widthText.isNotEmpty && heightText.isNotEmpty) {
            // 如果同时提供了宽度和高度
            scaleParam += '${widthText}:${heightText}';
          } else if (widthText.isNotEmpty) {
            // 如果只提供了宽度，高度按比例缩放
            scaleParam += '${widthText}:-1';
          } else {
            // 如果只提供了高度，宽度按比例缩放
            scaleParam += '-1:${heightText}';
          }

          commandParts.addAll(['-vf', scaleParam]);
        }

        // Add CRF if provided
        if (_selectedCrf >= 0 && _selectedCrf <= 51) {
          commandParts.addAll(['-crf', _selectedCrf.toInt().toString()]);
        }

        // Add preset if provided
        if (_selectedPreset != null && _selectedPreset!.isNotEmpty) {
          commandParts.addAll(['-preset', _selectedPreset!]);
        }

        // Add video bitrate if provided
        if (_selectedVideoBitrate != null &&
            _selectedVideoBitrate!.isNotEmpty) {
          commandParts.addAll(['-b:v', _selectedVideoBitrate!]);
        }

        // Add audio settings
        commandParts.addAll(['-c:a', 'aac']);
        if (_selectedAudioBitrate != null &&
            _selectedAudioBitrate!.isNotEmpty) {
          commandParts.addAll(['-b:a', _selectedAudioBitrate!]);
        }

        // Add output path
        commandParts.add('-y');
        commandParts.add(_outputVideoPath!);

        final command = commandParts.join(' ');

        if (kDebugMode) {
          print('FFmpeg command: $command');
        }

        // Use a Completer to handle async completion
        final completer = Completer<void>();

        // Enable statistics callback
        FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
          if (kDebugMode) {
            print(
              'Statistics: time=${statistics.getTime()}, videoFrameNumber=${statistics.getVideoFrameNumber()}',
            );
          }

          if (_videoDuration != null && statistics.getTime() > 0) {
            final progress = (statistics.getTime() / _videoDuration!).clamp(
              0.0,
              1.0,
            );
            if (kDebugMode) {
              print('Progress: $progress');
            }
            setState(() {
              _compressionProgress = progress;
              _status =
                  'Compressing video ${i + 1} of ${_inputVideoPaths.length}... ${(_compressionProgress * 100).toStringAsFixed(1)}%';
            });
          } else if (statistics.getVideoFrameNumber() > 0) {
            // If we can't calculate based on time, at least show that progress is happening
            setState(() {
              _status =
                  'Compressing video ${i + 1} of ${_inputVideoPaths.length}... Frame: ${statistics.getVideoFrameNumber()}';
            });
          }
        });

        // Execute FFmpeg command with async callback
        FFmpegKit.executeAsync(
          command,
          (session) async {
            // Session completed callback
            final returnCode = await session.getReturnCode();

            // Disable statistics callback
            FFmpegKitConfig.enableStatisticsCallback(
              (Statistics statistics) {},
            );

            if (ReturnCode.isSuccess(returnCode)) {
              final outputFile = File(_outputVideoPath!);
              if (await outputFile.exists()) {
                final inputSize = await inputFile.length();
                final outputSize = await outputFile.length();
                final compressionRatio = (1 - (outputSize / inputSize)) * 100;

                setState(() {
                  _status =
                      'Compression completed for video ${i + 1} of ${_inputVideoPaths.length}!\n'
                      'Input size: ${_formatBytes(inputSize)}\n'
                      'Output size: ${_formatBytes(outputSize)}\n'
                      'Space saved: ${compressionRatio.toStringAsFixed(1)}%';
                });
              } else {
                setState(() {
                  _status = 'Compression failed: Output file not created';
                });
              }
            } else {
              final failStackTrace = await session.getFailStackTrace();
              setState(() {
                _status = 'Compression failed: $failStackTrace';
              });
            }

            completer.complete();
          },
          (log) {
            // Log callback - we can ignore this for now
            if (kDebugMode) {
              print('FFmpeg log: ${log.getMessage()}');
            }
          },
          (Statistics statistics) {
            // Statistics callback - this is the same as the global one but specific to this session
            if (kDebugMode) {
              print(
                'Session Statistics: time=${statistics.getTime()}, videoFrameNumber=${statistics.getVideoFrameNumber()}',
              );
            }

            if (_videoDuration != null && statistics.getTime() > 0) {
              final progress = (statistics.getTime() / _videoDuration!).clamp(
                0.0,
                1.0,
              );
              if (kDebugMode) {
                print('Session Progress: $progress');
              }
              setState(() {
                _compressionProgress = progress;
                _status =
                    'Compressing video ${i + 1} of ${_inputVideoPaths.length}... ${(_compressionProgress * 100).toStringAsFixed(1)}%';
              });
            } else if (statistics.getVideoFrameNumber() > 0) {
              // If we can't calculate based on time, at least show that progress is happening
              setState(() {
                _status =
                    'Compressing video ${i + 1} of ${_inputVideoPaths.length}... Frame: ${statistics.getVideoFrameNumber()}';
              });
            }
          },
        );

        // Wait for completion
        await completer.future;
      } catch (e) {
        setState(() {
          _status = 'Error during compression: $e';
        });
      }
    }

    setState(() {
      _isCompressing = false;
      _status = 'All videos compressed successfully!';
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isCompressing ? null : _pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Select Videos'),
                ),
                const SizedBox(width: 10),
                if (_inputVideoPaths.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed:
                        _isCompressing
                            ? null
                            : () {
                              setState(() {
                                _inputVideoPaths.clear();
                                _status = 'Select videos to compress';
                              });
                            },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 添加拖拽区域
            DropTarget(
              onDragDone: (detail) {
                if (!_isCompressing) {
                  final List<String> newPaths =
                      detail.files
                          .where(
                            (file) =>
                                file.path.toLowerCase().endsWith('.mp4') ||
                                file.path.toLowerCase().endsWith('.mov') ||
                                file.path.toLowerCase().endsWith('.avi') ||
                                file.path.toLowerCase().endsWith('.mkv') ||
                                file.path.toLowerCase().endsWith('.wmv') ||
                                file.path.toLowerCase().endsWith('.flv') ||
                                file.path.toLowerCase().endsWith('.webm'),
                          )
                          .map((file) => file.path)
                          .toList();

                  if (newPaths.isNotEmpty) {
                    setState(() {
                      _inputVideoPaths.addAll(newPaths);
                      _status =
                          'Added ${newPaths.length} videos via drag & drop. Total: ${_inputVideoPaths.length} videos.';
                    });
                  } else {
                    setState(() {
                      _status = 'No valid video files found in dropped files.';
                    });
                  }
                }
              },
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 36,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _inputVideoPaths.isEmpty
                          ? 'Drag and drop video files here'
                          : 'Drag and drop more videos here',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_inputVideoPaths.isNotEmpty) ...[
              Text('Selected ${_inputVideoPaths.length} videos:'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _inputVideoPaths.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_inputVideoPaths[index].split('/').last),
                      subtitle: Text(_inputVideoPaths[index]),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ] else
              const Text(
                'No videos selected. Tap "Select Videos" to choose videos for compression, or drag and drop video files into the area above.',
              ),
            const SizedBox(height: 16),
            const Text(
              'Compression Parameters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // CRF selector
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'CRF (lower = higher quality)',
                border: OutlineInputBorder(),
              ),
              child: Column(
                children: [
                  Slider(
                    value: _selectedCrf,
                    min: 0,
                    max: 51,
                    divisions: 51,
                    label: _selectedCrf.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _selectedCrf = value;
                      });
                    },
                  ),
                  Text('Value: ${_selectedCrf.round()}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Preset selector
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Preset',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPreset,
                  isDense: true,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPreset = newValue;
                    });
                  },
                  items:
                      <String>[
                        'ultrafast',
                        'superfast',
                        'veryfast',
                        'faster',
                        'fast',
                        'medium',
                        'slow',
                        'slower',
                        'veryslow',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Video bitrate selector
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Video Bitrate',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVideoBitrate,
                  isDense: true,
                  hint: const Text('Select video bitrate (optional)'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedVideoBitrate = newValue;
                    });
                  },
                  items:
                      <String>[
                        '500k',
                        '1000k',
                        '1500k',
                        '2000k',
                        '3000k',
                        '4000k',
                        '5000k',
                        '6000k',
                        '8000k',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Audio bitrate selector
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Audio Bitrate',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAudioBitrate,
                  isDense: true,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedAudioBitrate = newValue;
                    });
                  },
                  items:
                      <String>[
                        '64k',
                        '96k',
                        '128k',
                        '192k',
                        '256k',
                        '320k',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Resolution selector
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Resolution',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedResolution,
                  isDense: true,
                  hint: const Text('Select resolution (optional)'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedResolution = newValue;

                      // 根据选择的分辨率更新宽度和高度控制器
                      if (newValue != null) {
                        final parts = newValue.split('x');
                        if (parts.length == 2) {
                          _widthController.text = parts[0];
                          _heightController.text = parts[1];
                        } else if (newValue.endsWith('p')) {
                          // 处理720p, 1080p等格式
                          final width =
                              newValue == '240p'
                                  ? '426'
                                  : newValue == '360p'
                                  ? '640'
                                  : newValue == '480p'
                                  ? '854'
                                  : newValue == '720p'
                                  ? '1280'
                                  : newValue == '1080p'
                                  ? '1920'
                                  : '';
                          _widthController.text = width;
                          _heightController.text = newValue.substring(
                            0,
                            newValue.length - 1,
                          );
                        }
                      } else {
                        _widthController.clear();
                        _heightController.clear();
                      }
                    });
                  },
                  items:
                      <String>[
                        '320x240',
                        '480x360',
                        '640x480',
                        '800x600',
                        '1024x768',
                        '1280x720',
                        '1600x900',
                        '1920x1080',
                        '2560x1440',
                        '3840x2160',
                        '240p',
                        '360p',
                        '480p',
                        '720p',
                        '1080p',
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select resolution from dropdown for proportional scaling',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
                  _isCompressing || _inputVideoPaths.isEmpty
                      ? null
                      : _compressVideo,
              icon: const Icon(Icons.compress),
              label: const Text('Compress Videos'),
            ),
            const SizedBox(height: 16),
            if (_isCompressing) ...[
              LinearProgressIndicator(value: _compressionProgress),
              const SizedBox(height: 8),
            ],
            Text(_status),
          ],
        ),
      ),
    );
  }
}
