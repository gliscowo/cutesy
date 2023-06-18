import 'dart:math';

import 'package:meta/meta.dart';

abstract interface class Animatable<A extends Animatable<A>> {
  A interpolate(A next, double delta);
}

typedef Observer<T> = void Function(T);

///
/// A container which allows observing changes to its value.
/// Every time the value is <i>changed</i>, i.e.
/// {@code Objects.equals(value, newValue)} evaluates to {@code false},
/// all observers added via {@link #observe(Consumer)} will be notified
/// and passed the new value
///
/// @param <T> The type of object this observable holds
/// @see #observeAll(Runnable, Observable[])
///
class Observable<T> {
  final List<Observer<T>> _observers = [];
  T _value;

  /// Creates a new observable container with
  /// the given initial value
  Observable.create(this._value);

  ///
  /// Notify the given observer whenever <i>any</i> of the given observables
  /// are updated. Context-less version {@link #observeAll(Consumer, Observable[])} which
  /// allows observing multiple observables of different types
  ///
  /// @param observer    The observer to notify
  /// @param observables The list of observable to observe
  ///
  static void observeAll(void Function() observer, List<Observable<dynamic>> observables) {
    for (var observable in observables) {
      observable.observe((_) => observer());
    }
  }

  ///
  /// @return The current value stored in this container
  ///
  T get value => _value;

  ///
  /// Change the value stored in this container to {@code newValue}.
  /// Observers will only be notified if {@code Objects.equals(value, newValue)}
  /// evaluates to {@code false}
  ///
  /// @param newValue The new value to store
  ///
  void set(T newValue) {
    final oldValue = this.value;
    _value = newValue;

    if (_value != oldValue) {
      notifyObservers(newValue);
    }
  }

  void call(T newValue) => set(newValue);

  ///
  /// Add an observer function to be run every time
  /// the value stored in this container changes
  ///
  void observe(Observer<T> observer) {
    _observers.add(observer);
  }

  @protected
  void notifyObservers(T value) {
    for (var observer in _observers) {
      observer(value);
    }
  }
}

/// A container which holds an animatable object,
/// used to manage to properties of UI components. Extends
/// the {@link Observable} container so that changes in its value
/// can be propagated to the holder of the property
///
/// @param <A> The type of animatable object this property describes
class AnimatableProperty<A extends Animatable<A>> extends Observable<A> {
  Animation<A>? _animation;

  /// Creates a new animatable property with
  /// the given initial value
  AnimatableProperty.create(super.value) : super.create();

  /// Create an animation object which interpolates the state of this
  /// property from the current one to {@code to} in {@code duration}
  /// milliseconds, applying the given easing
  /// <p>
  /// This method replaces the current animation object of
  /// this property - it will not be updated anymore
  ///
  /// @param duration The duration of the animation to create, in milliseconds
  /// @param easing   The easing method to use
  /// @param to       The target state of this property
  /// @return The new animation of this property.
  ///
  Animation<A> animate(int duration, Easing easing, A to) {
    return _animation = Animation(duration, set, easing, value, to);
  }

  ///
  /// @return The current animation object of this property,
  /// potentially {@code null} if {@link #animate(int, Easing, Animatable)}
  /// was never called
  ///
  Animation<A>? get animation => _animation;

  ///
  /// Update the currently stored animation
  /// object of this property
  ///
  /// @param delta The duration of the last frame, in partial ticks
  ///
  void update(double delta) {
    if (_animation == null) return;
    _animation!.update(delta);
  }
}

typedef Easing = double Function(double);

/// An easing function which can smoothly move
/// an interpolation value from 0 to 1
abstract final class Easings {
  static double linear(double x) => x;

  static double sine(double x) => sin(x * pi - pi / 2) * 0.5 + 0.5;

  static double quadratic(double x) => x < 0.5 ? 2 * x * x : (1 - pow(-2 * x + 2, 2) / 2);

  static double cubic(double x) => x < 0.5 ? 4 * x * x * x : (1 - pow(-2 * x + 2, 3) / 2);

  static double quartic(double x) => x < 0.5 ? 8 * x * x * x * x : (1 - pow(-2 * x + 2, 4) / 2);

  static double expo(double x) {
    if (x == 0) return 0;
    if (x == 1) return 1;

    return x < 0.5 ? pow(2, 20 * x - 10) / 2 : (2 - pow(2, -20 * x + 10)) / 2;
  }
}

class Animation<A extends Animatable<A>> {
  final int _duration;

  double _delta = 0;
  AnimationDirection _direction = AnimationDirection.backwards;
  bool looping = false;

  final void Function(A) _setter;
  final Easing _easing;

  final A _from;
  final A _to;

  // TODO: animation events
  // final EventStream<Finished> finishedEvents = Finished.newStream();
  // boolean eventInvoked = true;

  Animation(this._duration, this._setter, this._easing, this._from, this._to);

  static ComposedAnimation compose(List<Animation> elements) => ComposedAnimation._(elements);

  void update(double delta) {
    if (_delta == _direction.targetDelta) {
      // TODO: animation events
      // if (!_eventInvoked) {
      //     _finishedEvents.sink().onFinished(_direction, _looping);
      //     _eventInvoked = true;
      // }

      if (looping) {
        reverse();
      } else {
        return;
      }
    }

    _delta = (_delta + (delta * 1000 / _duration) * _direction.multiplier).clamp(0, 1);
    _setter(_from.interpolate(_to, _easing(_delta)));
  }

  void forwards() => this._setDirection(AnimationDirection.forwards);
  void backwards() => this._setDirection(AnimationDirection.backwards);
  void reverse() => this._setDirection(_direction.reversed);

  void _setDirection(AnimationDirection direction) {
    if (_direction == direction) return;
    this._direction = direction;

    // TODO: animation events
    // this.eventInvoked = false;
  }

  AnimationDirection get direction => _direction;

  // public EventSource<Finished> finished() {
  //     return this.finishedEvents.source();
  // }

  // public interface Finished {
  //     void onFinished(Direction direction, boolean looping);

  //     static EventStream<Finished> newStream() {
  //         return new EventStream<>(subscribers -> (direction, looping) -> {
  //             for (var subscriber : subscribers) {
  //                 subscriber.onFinished(direction, looping);
  //             }
  //         });
  //     }
  // }
}

class ComposedAnimation {
  final List<Animation> _elements;

  ComposedAnimation._(this._elements);

  void forwards() {
    for (var animation in _elements) {
      animation.forwards();
    }
  }

  void backwards() {
    for (var animation in _elements) {
      animation.backwards();
    }
  }

  void reverse() {
    for (var animation in _elements) {
      animation.reverse();
    }
  }

  set looping(bool looping) {
    for (var animation in _elements) {
      animation.looping = looping;
    }
  }
}

enum AnimationDirection {
  forwards(1, 1),
  backwards(-1, 0);

  final int multiplier;
  final double targetDelta;

  const AnimationDirection(this.multiplier, this.targetDelta);

  AnimationDirection get reversed {
    switch (this) {
      case forwards:
        return backwards;
      case backwards:
        return forwards;
    }
  }
}
