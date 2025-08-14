import 'package:flutter/material.dart';
import 'media_crop_task.dart';
import 'media_crop_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Crop Task App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MediaCropManager _manager;
  final List<MediaCropTask> _allTasks = [];
  final Map<MediaCropTask, double> _taskProgress = {};
  QueueStatus? _currentStatus;
  bool _isManagerInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  void _initializeManager() {
    _manager = MediaCropManager(maxParallel: 2); // 최대 2개 병렬 실행

    // 스트림 구독
    _manager.taskAddedStream.listen((task) {
      setState(() {
        _allTasks.add(task);
        _taskProgress[task] = 0.0;
      });

      // 각 태스크의 진행률 스트림 구독
      task.progressStream.listen((progress) {
        setState(() {
          _taskProgress[task] = progress;
        });
      });
    });

    _manager.taskCompletedStream.listen((task) {
      setState(() {
        // UI 업데이트
      });
      _showSuccessDialog('태스크 완료: ${task.outputPath}');
    });

    _manager.taskFailedStream.listen((task) {
      setState(() {
        // UI 업데이트
      });
      _showErrorDialog('태스크 실패: ${task.outputPath}');
    });

    _manager.taskCancelledStream.listen((task) {
      setState(() {
        // UI 업데이트
      });
      _showInfoDialog('태스크 취소됨: ${task.outputPath}');
    });

    _manager.queueStatusStream.listen((status) {
      setState(() {
        _currentStatus = status;
      });
    });

    setState(() {
      _isManagerInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Crop Manager Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _clearAllTasks,
            icon: const Icon(Icons.clear_all),
            tooltip: '모든 태스크 제거',
          ),
        ],
      ),
      body: !_isManagerInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQueueStatusCard(),
                  const SizedBox(height: 16),
                  _buildTaskControlCard(),
                  const SizedBox(height: 16),
                  _buildTaskListCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildQueueStatusCard() {
    if (_currentStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('큐 상태를 불러오는 중...'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '큐 상태',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    '전체',
                    _currentStatus!.queueLength,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '대기',
                    _currentStatus!.pendingCount,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '실행',
                    _currentStatus!.runningCount,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '완료',
                    _currentStatus!.completedCount,
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '실패',
                    _currentStatus!.failedCount,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '취소',
                    _currentStatus!.cancelledCount,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTaskControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '태스크 추가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addVideoTask,
                    icon: const Icon(Icons.video_file),
                    label: const Text('비디오 크롭'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addImageTask,
                    icon: const Icon(Icons.image),
                    label: const Text('이미지 크롭'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addBatchTasks,
                    icon: const Icon(Icons.queue),
                    label: const Text('배치 태스크 (3개)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListCard() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '태스크 목록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text('총 ${_allTasks.length}개'),
                      if (_allTasks.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _clearAllTasks,
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('모든 태스크 지우기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[100],
                            foregroundColor: Colors.red[800],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 36),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _allTasks.isEmpty
                    ? const Center(
                        child: Text(
                          '태스크가 없습니다.\n위의 버튼을 눌러 태스크를 추가해보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _allTasks.length,
                        itemBuilder: (context, index) {
                          final task = _allTasks[index];
                          return _buildTaskItem(task, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(MediaCropTask task, int index) {
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case MediaCropStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case MediaCropStatus.running:
        statusColor = Colors.green;
        statusIcon = Icons.play_arrow;
        break;
      case MediaCropStatus.completed:
        statusColor = Colors.teal;
        statusIcon = Icons.check_circle;
        break;
      case MediaCropStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case MediaCropStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          '태스크 ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('입력: ${task.inputPath.split('\\').last}'),
            Text('출력: ${task.outputPath.split('\\').last}'),
            Text('크롭: ${task.width}x${task.height} @ (${task.x}, ${task.y})'),
            const SizedBox(height: 8),
            if (task.status == MediaCropStatus.running ||
                task.status == MediaCropStatus.completed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _taskProgress[task] ?? 0.0,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((_taskProgress[task] ?? 0.0) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.status == MediaCropStatus.running)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _taskProgress[task] ?? 0.0,
                  strokeWidth: 2,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            const SizedBox(width: 8),
            if (task.status == MediaCropStatus.running)
              IconButton(
                onPressed: () => _cancelTask(task),
                icon: const Icon(Icons.stop),
                tooltip: '태스크 취소',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[800],
                ),
              ),
            if (task.status == MediaCropStatus.pending)
              IconButton(
                onPressed: () => _removeTask(task),
                icon: const Icon(Icons.delete),
                tooltip: '태스크 제거',
              ),
          ],
        ),
      ),
    );
  }

  void _addVideoTask() {
    final task = MediaCropTask(
      inputPath: 'D:\\temp\\video.mp4',
      outputPath:
          'D:\\temp\\cropped_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      x: 100,
      y: 100,
      width: 640,
      height: 480,
    );
    _manager.addTask(task);
  }

  void _addImageTask() {
    final task = MediaCropTask(
      inputPath: 'D:\\temp\\image.jpg',
      outputPath:
          'D:\\temp\\cropped_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      x: 100,
      y: 100,
      width: 200,
      height: 200,
    );
    _manager.addTask(task);
  }

  void _addBatchTasks() {
    for (int i = 1; i <= 3; i++) {
      final task = MediaCropTask(
        inputPath: 'D:\\temp\\video$i.mp4',
        outputPath: 'D:\\temp\\batch_cropped_video$i.mp4',
        x: 100 * i,
        y: 100 * i,
        width: 640,
        height: 480,
      );
      _manager.addTask(task);
    }
  }

  void _removeTask(MediaCropTask task) {
    _manager.removeTask(task);
    setState(() {
      _allTasks.remove(task);
      _taskProgress.remove(task);
    });
  }

  void _cancelTask(MediaCropTask task) async {
    if (task.status == MediaCropStatus.running) {
      await task.cancel();
      setState(() {
        // UI 업데이트
      });
    }
  }

  void _clearAllTasks() {
    if (_allTasks.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 태스크 지우기'),
        content: Text(
          '정말로 모든 태스크 (${_allTasks.length}개)를 지우시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _manager.clearQueue();
              setState(() {
                _allTasks.clear();
                _taskProgress.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('모든 태스크가 제거되었습니다.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
