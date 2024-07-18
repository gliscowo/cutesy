import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import 'events.dart';
import 'math.dart';

abstract interface class Animatable<A extends Animatable<A>> {
  A interpolate(A next, double delta);
}

typedef Observer<T> = void Function(T value);

/// A container which allows observing changes to its value.
/// Every time the value is *changed*, i.e. [==] evaluates to `false`,
/// all observers added via [observe] will be notified
/// and passed the new value
///
/// To watch multiple observables for *any* change (without
/// evaluating the value), use [observeAll]
class Observable<T> {
  final List<Observer<T>> _observers = [];
  T _value;

  /// Create a new observable container holding [_value]
  Observable(this._value);

  /// Notify the given observer whenever *any* of the given observables
  /// are updated. Context-less version {@link #observeAll(Consumer, Observable[])} which
  /// allows observing multiple observables of different types
  ///
  /// @param observer    The observer to notify
  /// @param observables The list of observable to observe
  static void observeAll(void Function() observer, List<Observable<dynamic>> observables) {
    for (var observable in observables) {
      observable.observe((_) => observer());
    }
  }

  /// The current value stored in this container
  T get value => _value;

  /// Change the value stored in this container to [newValue].
  /// Only if [==] evaluates to `false` will observers be notified
  void set(T newValue) {
    final oldValue = this.value;
    _value = newValue;

    if (_value != oldValue) {
      notifyObservers(newValue);
    }
  }

  void call(T newValue) => set(newValue);

  /// Add an observer function to be run every time
  /// the value stored in this container changes
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

extension Observe<T> on T {
  Observable<T> get observable => Observable(this);
}

/// A container which holds an animatable object,
/// used to manage to properties of UI widgets. Extends
/// the [Observable] container so that changes in its value
/// can be propagated to the holder of the property
class AnimatableProperty<A> extends Observable<A> {
  final A Function(A from, A to, double delta) _interpolator;
  Animation<A>? _animation;

  AnimatableProperty(super.value, this._interpolator);

  /// Create a new animatable property with value [initial]
  static AnimatableProperty<A> fromAnimatable<A extends Animatable<A>>(A initial) {
    return AnimatableProperty(initial, (from, to, delta) => from.interpolate(to, delta));
  }

  /// Create an animation object which interpolates the state of this
  /// property from the current one to [to] in [duration]
  /// milliseconds, applying [easing]
  ///
  /// This method replaces the current animation object of
  /// this property - it will not be updated anymore
  Animation<A> animate(int duration, Easing easing, A to) {
    return _animation = Animation(duration, _interpolator, set, easing, value, to);
  }

  /// The current animation object of this property,
  /// potentially `null` if [animate] was never called
  Animation<A>? get animation => _animation;

  /// Update the currently stored animation object of this property,
  /// assuming that [delta] seconds have passed since the last call
  void update(double delta) {
    if (_animation == null) return;
    _animation!.update(delta);
  }
}

extension Animate<T extends Animatable<T>> on T {
  AnimatableProperty<T> get animatable => AnimatableProperty.fromAnimatable(this);
}

extension AnimatableColor on Color {
  AnimatableProperty<Color> get animatable =>
      AnimatableProperty(this, (from, to, delta) => from.interpolate(to, delta));

  Color interpolate(Color next, double delta) {
    return Color.rgb(
      r.lerp(delta, next.r),
      g.lerp(delta, next.g),
      b.lerp(delta, next.b),
      a.lerp(delta, next.a),
    );
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

typedef AnimationFinished = ({AnimationDirection direction, bool looping});

class Animation<A> {
  final int _duration;

  double _delta = 0;
  AnimationDirection _direction = AnimationDirection.backwards;
  bool looping = false;

  final A Function(A from, A to, double delta) _interpolator;
  final void Function(A) _setter;
  final Easing _easing;

  final A _from;
  final A _to;

  final EventStream<AnimationFinished, void> _finishedEvents = EventStream.withoutResult();
  bool _eventInvoked = true;

  Animation(this._duration, this._interpolator, this._setter, this._easing, this._from, this._to);

  static ComposedAnimation compose(List<Animation<dynamic>> elements) => ComposedAnimation._(elements);

  void update(double delta) {
    if (_delta == _direction.targetDelta) {
      if (!_eventInvoked) {
        _finishedEvents.dispatch((direction: _direction, looping: looping));
        _eventInvoked = true;
      }

      if (looping) {
        reverse();
      } else {
        return;
      }
    }

    _delta = (_delta + (delta * 1000 / _duration) * _direction.multiplier).clamp(0, 1);
    _setter(_interpolator(_from, _to, _easing(_delta)));
  }

  void forwards() => this._setDirection(AnimationDirection.forwards);
  void backwards() => this._setDirection(AnimationDirection.backwards);
  void reverse() => this._setDirection(_direction.reversed);

  void _setDirection(AnimationDirection direction) {
    if (_direction == direction) return;
    this._direction = direction;

    _eventInvoked = false;
  }

  AnimationDirection get direction => _direction;
}

class ComposedAnimation {
  final List<Animation<dynamic>> _elements;

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
