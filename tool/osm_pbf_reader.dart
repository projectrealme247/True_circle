import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal pure-Dart OSM PBF reader (nodes, dense nodes, ways; zlib/raw blobs).
///
/// Spec: https://wiki.openstreetmap.org/wiki/PBF_Format
class OsmPbfReader {
  OsmPbfReader(this.path);

  final String path;

  /// Streams every primitive block in file order (nodes precede ways).
  Stream<OsmPrimitiveBlock> blocks() async* {
    final raf = await File(path).open();
    try {
      final length = await raf.length();
      var offset = 0;
      while (offset < length) {
        final headerLen = ByteData.sublistView(await raf.read(4)).getUint32(0);
        final header = _BlobHeader.parse(await raf.read(headerLen));
        final blob = await raf.read(header.dataSize);
        offset += 4 + headerLen + header.dataSize;
        if (header.type != 'OSMData') continue;
        yield OsmPrimitiveBlock._parse(_decodeBlob(blob));
      }
    } finally {
      await raf.close();
    }
  }
}

class OsmNode {
  OsmNode(this.id, this.lat, this.lon, this.tags);
  final int id;
  final double lat;
  final double lon;
  final Map<String, String> tags;
}

class OsmWay {
  OsmWay(this.id, this.refs, this.tags);
  final int id;
  final List<int> refs;
  final Map<String, String> tags;
}

class OsmPrimitiveBlock {
  OsmPrimitiveBlock._(this.nodes, this.ways);

  final List<OsmNode> nodes;
  final List<OsmWay> ways;

  factory OsmPrimitiveBlock._parse(Uint8List data) {
    final strings = <String>[];
    final groups = <Uint8List>[];
    var granularity = 100;
    var latOffset = 0;
    var lonOffset = 0;

    final r = _Pb(data);
    while (!r.done) {
      final tag = r.varint();
      switch (tag >> 3) {
        case 1:
          final st = _Pb(r.bytes());
          while (!st.done) {
            if (st.varint() >> 3 == 1) {
              strings.add(utf8.decode(st.bytes(), allowMalformed: true));
            }
          }
        case 2:
          groups.add(r.bytes());
        case 17:
          granularity = r.varint();
        case 19:
          latOffset = r.varint();
        case 20:
          lonOffset = r.varint();
        default:
          r.skip(tag & 7);
      }
    }

    double lat(int raw) => 1e-9 * (latOffset + granularity * raw);
    double lon(int raw) => 1e-9 * (lonOffset + granularity * raw);

    final nodes = <OsmNode>[];
    final ways = <OsmWay>[];
    for (final group in groups) {
      final g = _Pb(group);
      while (!g.done) {
        final tag = g.varint();
        switch (tag >> 3) {
          case 1:
            nodes.add(_parseNode(g.bytes(), strings, lat, lon));
          case 2:
            _parseDense(g.bytes(), strings, lat, lon, nodes);
          case 3:
            ways.add(_parseWay(g.bytes(), strings));
          default:
            g.skip(tag & 7);
        }
      }
    }
    return OsmPrimitiveBlock._(nodes, ways);
  }
}

OsmNode _parseNode(
  Uint8List data,
  List<String> strings,
  double Function(int) lat,
  double Function(int) lon,
) {
  var id = 0, rawLat = 0, rawLon = 0;
  var keys = <int>[], vals = <int>[];
  final r = _Pb(data);
  while (!r.done) {
    final tag = r.varint();
    switch (tag >> 3) {
      case 1:
        id = _zigzag(r.varint());
      case 2:
        keys = r.packedVarints();
      case 3:
        vals = r.packedVarints();
      case 8:
        rawLat = _zigzag(r.varint());
      case 9:
        rawLon = _zigzag(r.varint());
      default:
        r.skip(tag & 7);
    }
  }
  return OsmNode(id, lat(rawLat), lon(rawLon), _tags(keys, vals, strings));
}

void _parseDense(
  Uint8List data,
  List<String> strings,
  double Function(int) lat,
  double Function(int) lon,
  List<OsmNode> out,
) {
  var ids = <int>[], lats = <int>[], lons = <int>[], kv = <int>[];
  final r = _Pb(data);
  while (!r.done) {
    final tag = r.varint();
    switch (tag >> 3) {
      case 1:
        ids = r.packedVarints();
      case 8:
        lats = r.packedVarints();
      case 9:
        lons = r.packedVarints();
      case 10:
        kv = r.packedVarints();
      default:
        r.skip(tag & 7);
    }
  }
  var id = 0, rawLat = 0, rawLon = 0, k = 0;
  for (var i = 0; i < ids.length; i++) {
    id += _zigzag(ids[i]);
    rawLat += _zigzag(lats[i]);
    rawLon += _zigzag(lons[i]);
    Map<String, String> tags = const {};
    if (k < kv.length) {
      while (k < kv.length && kv[k] != 0) {
        if (tags.isEmpty) tags = {};
        tags[strings[kv[k]]] = strings[kv[k + 1]];
        k += 2;
      }
      k++;
    }
    out.add(OsmNode(id, lat(rawLat), lon(rawLon), tags));
  }
}

OsmWay _parseWay(Uint8List data, List<String> strings) {
  var id = 0;
  var keys = <int>[], vals = <int>[], refs = <int>[];
  final r = _Pb(data);
  while (!r.done) {
    final tag = r.varint();
    switch (tag >> 3) {
      case 1:
        id = r.varint();
      case 2:
        keys = r.packedVarints();
      case 3:
        vals = r.packedVarints();
      case 8:
        refs = r.packedVarints();
      default:
        r.skip(tag & 7);
    }
  }
  var ref = 0;
  final absolute = [for (final delta in refs) ref += _zigzag(delta)];
  return OsmWay(id, absolute, _tags(keys, vals, strings));
}

Map<String, String> _tags(List<int> keys, List<int> vals, List<String> strings) {
  if (keys.isEmpty) return const {};
  return {
    for (var i = 0; i < keys.length; i++) strings[keys[i]]: strings[vals[i]],
  };
}

int _zigzag(int n) => (n >> 1) ^ -(n & 1);

Uint8List _decodeBlob(Uint8List data) {
  final r = _Pb(data);
  while (!r.done) {
    final tag = r.varint();
    switch (tag >> 3) {
      case 1:
        return r.bytes();
      case 3:
        return Uint8List.fromList(zlib.decode(r.bytes()));
      case 2:
        r.varint();
      default:
        if ((tag >> 3) >= 4 && (tag & 7) == 2) {
          throw UnsupportedError('Unsupported PBF blob compression (field ${tag >> 3})');
        }
        r.skip(tag & 7);
    }
  }
  throw const FormatException('Empty PBF blob');
}

class _BlobHeader {
  _BlobHeader(this.type, this.dataSize);
  final String type;
  final int dataSize;

  factory _BlobHeader.parse(Uint8List data) {
    var type = '';
    var size = 0;
    final r = _Pb(data);
    while (!r.done) {
      final tag = r.varint();
      switch (tag >> 3) {
        case 1:
          type = utf8.decode(r.bytes());
        case 3:
          size = r.varint();
        default:
          r.skip(tag & 7);
      }
    }
    return _BlobHeader(type, size);
  }
}

/// Protobuf wire-format cursor.
class _Pb {
  _Pb(this._b);
  final Uint8List _b;
  int _i = 0;

  bool get done => _i >= _b.length;

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = _b[_i++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return result;
      shift += 7;
    }
  }

  Uint8List bytes() {
    final len = varint();
    final out = Uint8List.sublistView(_b, _i, _i + len);
    _i += len;
    return out;
  }

  List<int> packedVarints() {
    final len = varint();
    final end = _i + len;
    final out = <int>[];
    while (_i < end) {
      out.add(varint());
    }
    return out;
  }

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        varint();
      case 1:
        _i += 8;
      case 2:
        final len = varint();
        _i += len;
      case 5:
        _i += 4;
      default:
        throw FormatException('Unknown protobuf wire type $wireType');
    }
  }
}
