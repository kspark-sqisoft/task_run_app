import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Crop 작업 상태
enum MediaCropStatus { pending, running, completed, failed, cancelled }

/// MediaCropTask - FFmpeg crop 작업 단위
class MediaCropTask {
  static const String _ffmpegPath = 'C:\\ffmpeg\\bin\\ffmpeg.exe';

  final String inputPath;
  final String outputPath;
  final int x, y, width, height;

  MediaCropStatus status = MediaCropStatus.pending;
  final _progressController = StreamController<double>.broadcast();
  final _completeController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _cancelController = StreamController<void>.broadcast();

  Stream<double> get progressStream => _progressController.stream;
  Stream<void> get completeStream => _completeController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<void> get cancelStream => _cancelController.stream;

  Process? _currentProcess;
  bool _isCancelled = false;

  MediaCropTask({
    required this.inputPath,
    required this.outputPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Future<void> run() async {
    try {
      status = MediaCropStatus.running;
      final cropFilter = 'crop=$width:$height:$x:$y';

      // 입력 파일 존재 확인
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('입력 파일을 찾을 수 없습니다: $inputPath');
      }

      // 파일 확장자 확인하여 이미지인지 비디오인지 판단
      final isImage =
          inputPath.toLowerCase().endsWith('.jpg') ||
          inputPath.toLowerCase().endsWith('.jpeg') ||
          inputPath.toLowerCase().endsWith('.png') ||
          inputPath.toLowerCase().endsWith('.bmp') ||
          inputPath.toLowerCase().endsWith('.gif');

      if (isImage) {
        // 이미지의 경우 단계별 진행률 표시
        _progressController.add(0.1); // 시작
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isCancelled) return;

        _progressController.add(0.3); // 처리 중

        // FFmpeg 실행
        final process = await Process.start(_ffmpegPath, [
          '-i',
          inputPath,
          '-vf',
          cropFilter,
          '-y',
          outputPath,
        ]);

        _currentProcess = process;

        // stdout과 stderr 스트림 처리
        process.stdout.transform(utf8.decoder).listen((data) {
          if (!_isCancelled) {
            _parseProgress(data);
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          if (!_isCancelled) {
            _parseProgress(data);
          }
        });

        // 프로세스 완료 대기
        final exitCode = await process.exitCode;

        if (_isCancelled) return;

        if (exitCode == 0) {
          _progressController.add(0.8); // 거의 완료
          await Future.delayed(const Duration(milliseconds: 100));
          if (_isCancelled) return;

          _progressController.add(1.0); // 완료
          status = MediaCropStatus.completed;
          _completeController.add(null);
          print('[MediaCropTask] 완료: $outputPath');
        } else {
          status = MediaCropStatus.failed;
          final errorMsg = 'FFmpeg 실행 실패 (종료 코드: $exitCode)';
          _errorController.add(errorMsg);
          throw Exception(errorMsg);
        }
      } else {
        // 비디오의 경우 기존 방식 (실시간 진행률)
        _progressController.add(0.0); // 시작

        // FFmpeg 실행
        final process = await Process.start(_ffmpegPath, [
          '-i',
          inputPath,
          '-vf',
          cropFilter,
          '-y',
          outputPath,
        ]);

        _currentProcess = process;

        // stdout과 stderr 스트림 처리
        process.stdout.transform(utf8.decoder).listen((data) {
          if (!_isCancelled) {
            _parseProgress(data);
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          if (!_isCancelled) {
            _parseProgress(data);
          }
        });

        // 프로세스 완료 대기
        final exitCode = await process.exitCode;

        if (_isCancelled) return;

        if (exitCode == 0) {
          _progressController.add(1.0); // 100% 완료
          status = MediaCropStatus.completed;
          _completeController.add(null);
          print('[MediaCropTask] 완료: $outputPath');
        } else {
          status = MediaCropStatus.failed;
          final errorMsg = 'FFmpeg 실행 실패 (종료 코드: $exitCode)';
          _errorController.add(errorMsg);
          throw Exception(errorMsg);
        }
      }
    } catch (e) {
      status = MediaCropStatus.failed;
      final errorMsg = 'MediaCropTask 실행 중 오류: $e';
      _errorController.add(errorMsg);
      print('[MediaCropTask] 오류: $errorMsg');
      rethrow;
    }
  }

  /// FFmpeg 출력에서 진행률 파싱
  void _parseProgress(String line) {
    try {
      // FFmpeg 진행률 출력 예시: "frame= 1234 fps= 25 q=28.0 size= 1024kB time=00:00:49.36 bitrate= 170.0kbits/s speed=1.0x"
      if (line.contains('time=')) {
        final timeMatch = RegExp(
          r'time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})',
        ).firstMatch(line);
        if (timeMatch != null) {
          final hours = int.parse(timeMatch.group(1)!);
          final minutes = int.parse(timeMatch.group(2)!);
          final seconds = int.parse(timeMatch.group(3)!);
          final centiseconds = int.parse(timeMatch.group(4)!);

          // 총 시간을 초 단위로 변환
          final currentTime =
              hours * 3600 + minutes * 60 + seconds + centiseconds / 100;

          // 예상 총 길이 (입력 파일에서 가져와야 하지만, 여기서는 예시로 60초로 가정)
          // 실제 구현에서는 MediaInfo나 다른 방법으로 입력 파일 길이를 먼저 확인해야 함
          const estimatedTotalDuration = 60.0; // 초 단위

          if (estimatedTotalDuration > 0) {
            final progress = (currentTime / estimatedTotalDuration).clamp(
              0.0,
              1.0,
            );
            _progressController.add(progress);
            print(
              '[MediaCropTask] 진행률: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        }
      }
    } catch (e) {
      // 진행률 파싱 실패 시 무시하고 계속 진행
      print('[MediaCropTask] 진행률 파싱 오류: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _progressController.close();
    _completeController.close();
    _errorController.close();
    _cancelController.close();
  }

  /// 태스크 취소
  Future<void> cancel() async {
    if (status == MediaCropStatus.running && _currentProcess != null) {
      _isCancelled = true;
      status = MediaCropStatus.cancelled;

      try {
        // FFmpeg 프로세스 종료
        _currentProcess!.kill();
        await _currentProcess!.exitCode;
        print('[MediaCropTask] 취소됨: $outputPath');

        // 취소 이벤트 발생
        _cancelController.add(null);
      } catch (e) {
        print('[MediaCropTask] 취소 중 오류: $e');
      }
    }
  }
}
