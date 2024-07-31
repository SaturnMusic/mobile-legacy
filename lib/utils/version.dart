// version.dart
/* Copyright (c) 2021, Matthew Barbour.
All rights reserved.
https://github.com/dartninja/version

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of these conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

/// Provides version objects to enforce conformance to the Semantic Versioning 2.0 spec. The spec can be read at http://semver.org/
library version;

/// Provides immutable storage and comparison of semantic version numbers.
class Version implements Comparable<Version> {
  static final RegExp _versionRegex = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(-(\d+|[0-9A-Za-z\-\.]+))?(\+([0-9A-Za-z\-\.]+))?$');
  static final RegExp _buildRegex = RegExp(r'^[0-9A-Za-z\-.]+$');
  static final RegExp _preReleaseRegex = RegExp(r'^[0-9A-Za-z\-]+$');

  /// The major number of the version, incremented when making breaking changes.
  final int major;

  /// The minor number of the version, incremented when adding new functionality in a backwards-compatible manner.
  final int minor;

  /// The patch number of the version, incremented when making backwards-compatible bug fixes.
  final int patch;

  /// Build information relevant to the version. Does not contribute to sorting.
  final String build;

  /// Pre-release information segments.
  final List<String> _preRelease;

  /// Indicates that the version is a pre-release. Returns true if preRelease has any segments, otherwise false.
  bool get isPreRelease => _preRelease.isNotEmpty;

  /// Creates a new instance of [Version].
  Version(
    this.major,
    this.minor,
    this.patch, {
    List<String> preRelease = const <String>[],
    this.build = '',
  }) : _preRelease = preRelease {
    for (int i = 0; i < _preRelease.length; i++) {
      if (_preRelease[i].trim().isEmpty) {
        throw ArgumentError('Pre-release segments must not be empty.');
      }
      // Just in case
      _preRelease[i] = _preRelease[i].toString();
      if (!_preReleaseRegex.hasMatch(_preRelease[i])) {
        throw const FormatException('Pre-release segments must only contain [0-9A-Za-z-].');
      }
    }
    if (build.isNotEmpty && !_buildRegex.hasMatch(build)) {
      throw const FormatException('Build must only contain [0-9A-Za-z-.].');
    }

    if (major < 0 || minor < 0 || patch < 0) {
      throw ArgumentError('Version numbers must be non-negative.');
    }
  }

  @override
  int get hashCode => toString().hashCode;

  /// Pre-release information segments.
  List<String> get preRelease => List<String>.from(_preRelease);

  /// Determines whether the left-hand [Version] represents a lower precedence than the right-hand [Version].
  bool operator <(Object o) => o is Version && _compare(this, o) < 0;

  /// Determines whether the left-hand [Version] represents an equal or lower precedence than the right-hand [Version].
  bool operator <=(Object o) => o is Version && _compare(this, o) <= 0;

  /// Determines whether the left-hand [Version] represents an equal precedence to the right-hand [Version].
  @override
  bool operator ==(Object o) => o is Version && _compare(this, o) == 0;

  /// Determines whether the left-hand [Version] represents a greater precedence than the right-hand [Version].
  bool operator >(Object o) => o is Version && _compare(this, o) > 0;

  /// Determines whether the left-hand [Version] represents an equal or greater precedence than the right-hand [Version].
  bool operator >=(Object o) => o is Version && _compare(this, o) >= 0;

  @override
  int compareTo(Version? other) {
    if (other == null) {
      throw ArgumentError.notNull('other');
    }

    return _compare(this, other);
  }

  /// Creates a new [Version] with the [major] version number incremented.
  Version incrementMajor() => Version(major + 1, 0, 0);

  /// Creates a new [Version] with the [minor] version number incremented.
  Version incrementMinor() => Version(major, minor + 1, 0);

  /// Creates a new [Version] with the [patch] version number incremented.
  Version incrementPatch() => Version(major, minor, patch + 1);

  /// Creates a new [Version] with the right-most numeric [preRelease] segment incremented.
  Version incrementPreRelease() {
    if (!isPreRelease) {
      throw Exception('Cannot increment pre-release on a non-pre-release [Version]');
    }
    var newPreRelease = preRelease;

    var found = false;
    for (var i = newPreRelease.length - 1; i >= 0; i--) {
      var segment = newPreRelease[i];
      if (Version._isNumeric(segment)) {
        var intVal = int.parse(segment);
        intVal++;
        newPreRelease[i] = intVal.toString();
        found = true;
        break;
      }
    }
    if (!found) {
      newPreRelease.add('1');
    }

    return Version(major, minor, patch, preRelease: newPreRelease);
  }

  @override
  String toString() {
    final StringBuffer output = StringBuffer('$major.$minor.$patch');
    if (_preRelease.isNotEmpty) {
      output.write("-${_preRelease.join('.')}");
    }
    if (build.trim().isNotEmpty) {
      output.write('+${build.trim()}');
    }
    return output.toString();
  }

  /// Creates a [Version] instance from a string.
  static Version parse(String versionString) {
    versionString = versionString.trim();
    if (versionString.startsWith('v')) {
      versionString = versionString.substring(1);
    }
    if (versionString.isEmpty) {
      throw const FormatException('Cannot parse empty string into version');
    }
    if (!_versionRegex.hasMatch(versionString)) {
      throw const FormatException('Not a properly formatted version string');
    }
    final Match m = _versionRegex.firstMatch(versionString)!;
    final String version = m.group(1)!;

    int? major, minor, patch;
    final List<String> parts = version.split('.');
    major = int.parse(parts[0]);
    if (parts.length > 1) {
      minor = int.parse(parts[1]);
      if (parts.length > 2) {
        patch = int.parse(parts[2]);
      }
    }

    final String preReleaseString = m.group(3) ?? '';
    List<String> preReleaseList = <String>[];
    if (preReleaseString.trim().isNotEmpty) {
      preReleaseList = preReleaseString.split('.');
    }
    final String build = m.group(5) ?? '';

    return Version(major, minor ?? 0, patch ?? 0, preRelease: preReleaseList, build: build);
  }

  static Version? tryParse(String source) {
    try {
      return Version.parse(source);
    } on FormatException {
      return null;
    }
  }

  static bool _isNumeric(String? s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }

  static int _compare(Version? a, Version? b) {
    if (a == null) {
      throw ArgumentError.notNull('a');
    }

    if (b == null) {
      throw ArgumentError.notNull('b');
    }

    if (a.major > b.major) return 1;
    if (a.major < b.major) return -1;

    if (a.minor > b.minor) return 1;
    if (a.minor < b.minor) return -1;

    if (a.patch > b.patch) return 1;
    if (a.patch < b.patch) return -1;

    if (a.preRelease.isEmpty) {
      if (b.preRelease.isEmpty) {
        return 0;
      } else {
        return 1;
      }
    } else if (b.preRelease.isEmpty) {
      return -1;
    } else {
      int preReleaseMax = a.preRelease.length;
      if (b.preRelease.length > a.preRelease.length) {
        preReleaseMax = b.preRelease.length;
      }

      for (int i = 0; i < preReleaseMax; i++) {
        if (b.preRelease.length <= i) {
          return 1;
        } else if (a.preRelease.length <= i) {
          return -1;
        }

        if (a.preRelease[i] == b.preRelease[i]) continue;

        final bool aNumeric = _isNumeric(a.preRelease[i]);
        final bool bNumeric = _isNumeric(b.preRelease[i]);

        if (aNumeric && bNumeric) {
          final double aNumber = double.parse(a.preRelease[i]);
          final double bNumber = double.parse(b.preRelease[i]);
          if (aNumber > bNumber) {
            return 1;
          } else {
            return -1;
          }
        } else if (bNumeric) {
          return 1;
        } else if (aNumeric) {
          return -1;
        } else {
          return a.preRelease[i].compareTo(b.preRelease[i]);
        }
      }
    }
    return 0;
  }
}
