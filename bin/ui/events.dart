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

class CharTypedEvent {
  final String chr;
  final int modifiers;
  CharTypedEvent(this.chr, this.modifiers);
}

class MouseButtonEvent {
  final double mouseX, mouseY;
  final int button;
  MouseButtonEvent(this.mouseX, this.mouseY, this.button);
}

class MouseScrollEvent {
  final double mouseX, mouseY, amount;
  MouseScrollEvent(this.mouseX, this.mouseY, this.amount);
}

class MouseDragEvent {
  final double mouseX, mouseY, deltaX, deltaY;
  final int button;
  MouseDragEvent(this.mouseX, this.mouseY, this.deltaX, this.deltaY, this.button);
}

class KeyPressEvent {
  final int keyCode, scanCode, modifiers;
  KeyPressEvent(this.keyCode, this.scanCode, this.modifiers);
}
