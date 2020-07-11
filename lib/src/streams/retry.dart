import 'dart:async';

import 'package:rxdart/src/streams/utils.dart';

/// Creates a [Stream] that will recreate and re-listen to the source
/// [Stream] the specified number of times until the [Stream] terminates
/// successfully.
///
/// If the retry count is not specified, it retries indefinitely. If the retry
/// count is met, but the Stream has not terminated successfully, a
/// [RetryError] will be thrown. The RetryError will contain all of the Errors
/// and StackTraces that caused the failure.
///
/// ### Example
///
///     RetryStream(() { Stream.fromIterable([1]); })
///         .listen((i) => print(i)); // Prints 1
///
///     RetryStream(() {
///          Stream.fromIterable([1])
///             .concatWith([ErrorStream(Error())]);
///        }, 1)
///        .listen(print, onError: (e, s) => print(e)); // Prints 1, 1, RetryError
class RetryStream<T> extends Stream<T> {
  /// The factory method used at subscription time
  final Stream<T> Function() streamFactory;

  /// The amount of retry attempts that will be made
  /// If null, then an indefinite amount of attempts will be made.
  final int? count;
  int _retryStep = 0;
  StreamController<T>? _controller;
  StreamSubscription<T>? _subscription;
  final _errors = <ErrorAndStacktrace>[];

  /// Constructs a [Stream] that will recreate and re-listen to the source
  /// [Stream] (created by the provided factory method) the specified number
  /// of times until the [Stream] terminates successfully.
  /// If [count] is not specified, it retries indefinitely.
  RetryStream(this.streamFactory, [this.count]);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    late void Function() retry;

    final combinedErrors = () => RetryError.withCount(
          count,
          _errors,
        );

    retry = () {
      _subscription = streamFactory().listen(_controller?.add,
          onError: (Object e, StackTrace? s) {
        _subscription?.cancel();

        _errors.add(ErrorAndStacktrace(e, s));

        if (count == _retryStep) {
          _controller
            ?..addError(combinedErrors())
            ..close();
        } else {
          ++_retryStep;
          retry();
        }
      }, onDone: _controller?.close, cancelOnError: false);
    };

    _controller ??= StreamController<T>(
        sync: true,
        onListen: retry,
        onPause: ([Future<dynamic>? resumeSignal]) =>
            _subscription?.pause(resumeSignal),
        onResume: () => _subscription?.resume(),
        onCancel: () => _subscription?.cancel());

    return _controller!.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
