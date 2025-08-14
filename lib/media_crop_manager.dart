import 'dart:async';
import 'package:task_run_app/media_crop_task.dart';

class MediaCropManager {
  final List<MediaCropTask> _queue = [];
  final int maxParallel;
  int _runningCount = 0;

  // 스트림 컨트롤러들
  final _taskAddedController = StreamController<MediaCropTask>.broadcast();
  final _taskCompletedController = StreamController<MediaCropTask>.broadcast();
  final _taskFailedController = StreamController<MediaCropTask>.broadcast();
  final _taskCancelledController = StreamController<MediaCropTask>.broadcast();
  final _queueStatusController = StreamController<QueueStatus>.broadcast();

  MediaCropManager({this.maxParallel = 2});

  // 스트림 getter들
  Stream<MediaCropTask> get taskAddedStream => _taskAddedController.stream;
  Stream<MediaCropTask> get taskCompletedStream =>
      _taskCompletedController.stream;
  Stream<MediaCropTask> get taskFailedStream => _taskFailedController.stream;
  Stream<MediaCropTask> get taskCancelledStream =>
      _taskCancelledController.stream;
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;

  // 큐 상태 getter들
  int get queueLength => _queue.length;
  int get runningCount => _runningCount;
  int get pendingCount =>
      _queue.where((t) => t.status == MediaCropStatus.pending).length;
  int get completedCount =>
      _queue.where((t) => t.status == MediaCropStatus.completed).length;
  int get failedCount =>
      _queue.where((t) => t.status == MediaCropStatus.failed).length;
  int get cancelledCount =>
      _queue.where((t) => t.status == MediaCropStatus.cancelled).length;

  void addTask(MediaCropTask task) {
    _queue.add(task);
    _taskAddedController.add(task);
    _updateQueueStatus();
    _tryRunNext();
  }

  void removeTask(MediaCropTask task) {
    _queue.remove(task);
    _updateQueueStatus();
  }

  void clearQueue() {
    _queue.clear();
    _updateQueueStatus();
  }

  void _tryRunNext() {
    if (_runningCount >= maxParallel) return;

    final pendingTasks = _queue.where(
      (t) => t.status == MediaCropStatus.pending,
    );
    if (pendingTasks.isEmpty) return;

    final task = pendingTasks.first;
    _runningCount++;
    _updateQueueStatus();

    task
        .run()
        .then((_) {
          _runningCount--;
          _taskCompletedController.add(task);
          _updateQueueStatus();
          _tryRunNext();
        })
        .catchError((error) {
          print('Task execution error: $error');
          _runningCount--;
          _taskFailedController.add(task);
          _updateQueueStatus();
          _tryRunNext();
        });
  }

  void _updateQueueStatus() {
    _queueStatusController.add(
      QueueStatus(
        queueLength: queueLength,
        runningCount: runningCount,
        pendingCount: pendingCount,
        completedCount: completedCount,
        failedCount: failedCount,
        cancelledCount: cancelledCount,
      ),
    );
  }

  void dispose() {
    _taskAddedController.close();
    _taskCompletedController.close();
    _taskFailedController.close();
    _taskCancelledController.close();
    _queueStatusController.close();
  }
}

class QueueStatus {
  final int queueLength;
  final int runningCount;
  final int pendingCount;
  final int completedCount;
  final int failedCount;
  final int cancelledCount;

  QueueStatus({
    required this.queueLength,
    required this.runningCount,
    required this.pendingCount,
    required this.completedCount,
    required this.failedCount,
    required this.cancelledCount,
  });

  @override
  String toString() {
    return 'QueueStatus(queueLength: $queueLength, runningCount: $runningCount, pendingCount: $pendingCount, completedCount: $completedCount, failedCount: $failedCount, cancelledCount: $cancelledCount)';
  }
}
