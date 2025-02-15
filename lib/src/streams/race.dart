import 'dart:async';

import 'package:rxdart/src/utils/subscription.dart';

/// Given two or more source streams, emit all of the items from only
/// the first of these streams to emit an item or notification.
///
/// If the provided streams is empty, the resulting sequence completes immediately
/// without emitting any items.
///
/// [Interactive marble diagram](http://rxmarbles.com/#amb)
///
/// ### Example
///
///     RaceStream([
///       TimerStream(1, Duration(days: 1)),
///       TimerStream(2, Duration(days: 2)),
///       TimerStream(3, Duration(seconds: 3))
///     ]).listen(print); // prints 3
class RaceStream<T> extends Stream<T> {
  final StreamController<T> _controller;

  /// Constructs a [Stream] which emits all events from a single [Stream]
  /// inside [streams]. The selected [Stream] is the first one which emits
  /// an event.
  /// After this event, all other [Stream]s in [streams] are discarded.
  RaceStream(Iterable<Stream<T>> streams)
      : _controller = _buildController(streams);

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  static StreamController<T> _buildController<T>(Iterable<Stream<T>> streams) {
    if (streams.isEmpty) {
      return StreamController<T>()..close();
    }

    late List<StreamSubscription<T>> subscriptions;
    late StreamController<T> controller;

    controller = StreamController<T>(
        sync: true,
        onListen: () {
          var index = 0;

          void reduceToWinner(int winnerIndex) {
            //ignore: cancel_subscriptions
            final winner = subscriptions.removeAt(winnerIndex);

            subscriptions.cancelAll();

            subscriptions = [winner];
          }

          void Function(T value) doUpdate(int index) => (T value) {
                try {
                  if (subscriptions.length > 1) reduceToWinner(index);

                  controller.add(value);
                } catch (e, s) {
                  controller.addError(e, s);
                }
              };

          subscriptions = streams
              .map((stream) => stream.listen(doUpdate(index++),
                  onError: controller.addError, onDone: controller.close))
              .toList();
        },
        onPause: () => subscriptions.pauseAll(),
        onResume: () => subscriptions.resumeAll(),
        onCancel: () => subscriptions.cancelAll());

    return controller;
  }
}
