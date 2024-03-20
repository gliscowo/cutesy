import 'dart:io';

import 'package:vector_math/vector_math.dart';

class Obj {
  final List<Vector3> vertices;
  final List<int> indices;
  final List<Vector2> uvs;
  final List<Vector3> normals;

  Obj(this.vertices, this.indices, this.uvs, this.normals);
}

Obj loadObj(File from) {
  final vertices = <Vector3>[];
  final indices = <int>[];
  final uvs = <Vector2>[];
  final normals = <Vector3>[];

  for (final line in from.readAsLinesSync()) {
    final parts = line.trim().split(RegExp(r"\s+"));

    switch (parts.first) {
      case 'v':
        vertices.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      case 'vt':
        uvs.add(Vector2(double.parse(parts[1]), double.parse(parts[2])));
      case 'vn':
        normals.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      case 'f':
        indices
          ..add(int.parse(parts[1].split("/").first))
          ..add(int.parse(parts[2].split("/").first))
          ..add(int.parse(parts[3].split("/").first));
    }
  }

  return Obj(vertices, indices, uvs, normals);
}
