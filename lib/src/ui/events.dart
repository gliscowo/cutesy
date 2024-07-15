typedef EventSource<E, R> = EventSubscription<E, R> Function(R Function(E) subscriber);

class EventStream<E, R> {
  final R Function(R, R) _resultReducer;
  final bool Function(R) _returnCondition;
  final R _defaultResult;

  final List<R Function(E)> _subscribers = [];

  EventStream(this._resultReducer, this._returnCondition, this._defaultResult);

  static EventStream<E, bool> withBoolResult<E>() => EventStream<E, bool>((p0, p1) => p0 || p1, (p0) => false, false);
  static EventStream<E, void> withoutResult<E>() => EventStream<E, void>((p0, p1) {}, (p0) => false, null);

  R dispatch(E event) {
    var result = _defaultResult;

    for (var subscriber in _subscribers) {
      result = _resultReducer(result, subscriber(event));
      if (_returnCondition(result)) return result;
    }

    return result;
  }

  EventSource<E, R> get source {
    return (subscriber) {
      _subscribers.add(subscriber);
      return EventSubscription._(this, subscriber);
    };
  }
}

class EventSubscription<E, R> {
  final EventStream<E, R> _stream;
  final R Function(E) _subscriber;
  EventSubscription._(this._stream, this._subscriber);

  void cancel() => _stream._subscribers.remove(_subscriber);
}

// Default event classes

typedef CharTypedEvent = ({String chr, int modifiers});
typedef MouseButtonEvent = ({double mouseX, double mouseY, int button});
typedef MouseScrollEvent = ({double mouseX, double mouseY, double amount});
typedef MouseDragEvent = ({double mouseX, double mouseY, double deltaX, double deltaY, int button});
typedef KeyPressEvent = ({int keyCode, int scanCode, int modifiers});
