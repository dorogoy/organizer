/// JSON decoding that rejects duplicate object members before a caller can
/// observe the resulting value. `dart:convert` intentionally keeps the last
/// member, which would hide catalogue and localization drift.
library;

import 'dart:convert';

/// A JSON failure with a precise source location.
final class StrictJsonFormatException extends FormatException {
  StrictJsonFormatException(String message, this._source, this._offset)
    : super(message, _source, _offset);

  final String _source;
  final int _offset;

  /// The complete source that failed. Unlike [FormatException.source], this
  /// strict decoder contract is never null.
  @override
  String get source => _source;

  /// The zero-based offset of the failure. Unlike [FormatException.offset],
  /// this strict decoder contract is never null.
  @override
  int get offset => _offset;

  int get line => '\n'.allMatches(source.substring(0, offset)).length + 1;
}

/// Decodes [source] while rejecting a repeated key in every JSON object.
Object? strictJsonDecode(String source) => _StrictJsonReader(source).read();

final class _StrictJsonReader {
  _StrictJsonReader(this.source);

  final String source;
  int _index = 0;

  Object? read() {
    _skipWhitespace();
    final value = _readValue();
    _skipWhitespace();
    if (_index != source.length) {
      _fail('unexpected trailing JSON content');
    }
    return value;
  }

  Object? _readValue() {
    if (_index == source.length) {
      _fail('expected a JSON value');
    }
    switch (source.codeUnitAt(_index)) {
      case 0x7b:
        return _readObject();
      case 0x5b:
        return _readArray();
      case 0x22:
        return _readString();
      case 0x74:
        return _readKeyword('true', true);
      case 0x66:
        return _readKeyword('false', false);
      case 0x6e:
        return _readKeyword('null', null);
      default:
        return _readNumber();
    }
  }

  Map<String, dynamic> _readObject() {
    _index++;
    _skipWhitespace();
    final result = <String, dynamic>{};
    if (_consume(0x7d)) {
      return result;
    }
    while (true) {
      if (_index == source.length || source.codeUnitAt(_index) != 0x22) {
        _fail('expected an object member name');
      }
      final keyOffset = _index;
      final key = _readString();
      if (result.containsKey(key)) {
        _fail('duplicate JSON member "$key"', keyOffset);
      }
      _skipWhitespace();
      _expect(0x3a, 'expected ":" after object member name');
      _skipWhitespace();
      result[key] = _readValue();
      _skipWhitespace();
      if (_consume(0x7d)) {
        return result;
      }
      _expect(0x2c, 'expected "," between object members');
      _skipWhitespace();
    }
  }

  List<dynamic> _readArray() {
    _index++;
    _skipWhitespace();
    final result = <dynamic>[];
    if (_consume(0x5d)) {
      return result;
    }
    while (true) {
      result.add(_readValue());
      _skipWhitespace();
      if (_consume(0x5d)) {
        return result;
      }
      _expect(0x2c, 'expected "," between array values');
      _skipWhitespace();
    }
  }

  String _readString() {
    final start = _index;
    _index++;
    while (_index < source.length) {
      final code = source.codeUnitAt(_index++);
      if (code == 0x22) {
        final literal = source.substring(start, _index);
        try {
          return jsonDecode(literal) as String;
        } on FormatException {
          _fail('invalid JSON string', start);
        }
      }
      if (code < 0x20) {
        _fail('unescaped control character in JSON string', _index - 1);
      }
      if (code == 0x5c) {
        if (_index == source.length) {
          _fail('unterminated JSON string', start);
        }
        final escape = source.codeUnitAt(_index++);
        if (!const <int>{
          0x22,
          0x5c,
          0x2f,
          0x62,
          0x66,
          0x6e,
          0x72,
          0x74,
          0x75,
        }.contains(escape)) {
          _fail('invalid JSON string escape', _index - 1);
        }
        if (escape == 0x75) {
          for (var i = 0; i < 4; i++) {
            if (_index == source.length || !_isHex(source.codeUnitAt(_index))) {
              _fail('invalid JSON unicode escape', _index);
            }
            _index++;
          }
        }
      }
    }
    _fail('unterminated JSON string', start);
  }

  Object _readNumber() {
    final start = _index;
    if (_consume(0x2d) && _index == source.length) {
      _fail('invalid JSON number', start);
    }
    if (_consume(0x30)) {
      // A leading zero may not be followed by another digit.
      if (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _fail('invalid JSON number', start);
      }
    } else {
      _requireDigits(start);
    }
    if (_consume(0x2e)) {
      _requireDigits(start);
    }
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      _index++;
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2b ||
              source.codeUnitAt(_index) == 0x2d)) {
        _index++;
      }
      _requireDigits(start);
    }
    try {
      return num.parse(source.substring(start, _index));
    } on FormatException {
      _fail('invalid JSON number', start);
    }
  }

  Object? _readKeyword(String keyword, Object? value) {
    if (!source.startsWith(keyword, _index)) {
      _fail('invalid JSON value');
    }
    _index += keyword.length;
    return value;
  }

  void _requireDigits(int start) {
    final first = _index;
    while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
      _index++;
    }
    if (_index == first) {
      _fail('invalid JSON number', start);
    }
  }

  bool _consume(int expected) {
    if (_index < source.length && source.codeUnitAt(_index) == expected) {
      _index++;
      return true;
    }
    return false;
  }

  void _expect(int expected, String message) {
    if (!_consume(expected)) {
      _fail(message);
    }
  }

  void _skipWhitespace() {
    while (_index < source.length &&
        const <int>{
          0x20,
          0x09,
          0x0a,
          0x0d,
        }.contains(source.codeUnitAt(_index))) {
      _index++;
    }
  }

  Never _fail(String message, [int? offset]) {
    final at = offset ?? _index;
    final line = '\n'.allMatches(source.substring(0, at)).length + 1;
    throw StrictJsonFormatException('$message at line $line', source, at);
  }
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

bool _isHex(int code) =>
    _isDigit(code) ||
    (code >= 0x41 && code <= 0x46) ||
    (code >= 0x61 && code <= 0x66);
