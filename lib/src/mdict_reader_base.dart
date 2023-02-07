import 'dart:io';
import 'dart:typed_data';
import "package:pointycastle/pointycastle.dart";
import 'package:xml/xml.dart';
import 'input_stream.dart';

class Key {
  String key;
  int offset;
  int length;
  Key(this.key, this.offset, [this.length = -1]);
}

class Record {
  int compSize;
  int decompSize;
  Record(this.compSize, this.decompSize);
}

class MdictReader {
  String path;
  late final Map<String, String> _header;
  late final double _version;
  late final int _numberWidth;
  late final List<Key> _keyList;
  late final List<Record> _recordList;
  late final int _recordBlockOffset;

  MdictReader(this.path) {
    var fin = FileInputStream(path, bufferSize: 64 * 1024);
    _header = _readHeader(fin);
    _version = double.parse(_header['GeneratedByEngineVersion']!);
    _numberWidth = _version >= 2.0 ? 8 : 4;
    _keyList = _read_keys(fin);
    _recordList = _readRecords(fin);
    _recordBlockOffset = fin.position;
    fin.close();
  }

  List<String> keys() {
    return _keyList.map((key) => key.key).toList();
  }

  dynamic query(String word) {
    var mdd = path.endsWith('.mdd');
    var keys = _keyList.where((key) => key.key == word).toList();
    var records = keys
        .map((key) => _readRecord(key.key, key.offset, key.length, mdd))
        .toList();
    if (mdd) {
      if (records.length == 0) {
        return null;
      }
      return records[0];
    }
    return records.join('\n---\n');
  }

  Map<String, String> _readHeader(FileInputStream fin) {
    var headerLength = fin.readUint32();
    var header = fin.readString(length: headerLength, utf8: false);
    fin.skip(4);
    return _parseHeader(header);
  }

  Map<String, String> _parseHeader(String header) {
    var attributes = <String, String>{};
    var doc = XmlDocument.parse(header);
    for (var a in doc.rootElement.attributes) {
      attributes[a.name.local] = a.value;
    }
    return attributes;
  }

  List<Key> _read_keys(FileInputStream fin) {
    var encrypted = _header['Encrypted'] == '2';
    var encrypted_value = _header['Encrypted'];
    var utf8 = _header['Encoding'] == 'UTF-8';
    var keyNumBlocks = _readNumber(fin);
    var keyNumEntries = _readNumber(fin);
    if (_version >= 2.0) {
      _readNumber(fin);
    }
    var keyIndexCompLen = _readNumber(fin);
    var keyBlocksLen = _readNumber(fin);
    if (_version >= 2.0) {
      fin.skip(4);
    }
    var compSize = List.filled(keyNumBlocks, 0);
    var decompSize = List.filled(keyNumBlocks, 0);
    var numEntries = List.filled(keyNumBlocks, 0);
    var indexCompBlock = fin.readBytes(keyIndexCompLen);
    if (encrypted) {
      var key = _computeKey(indexCompBlock);
      _decryptBlock(key, indexCompBlock, 8);
    }
    var indexDs = _version >= 2.0 ? _decompressBlock(indexCompBlock)
            : BytesInputStream(indexCompBlock);
    for (var i = 0; i < keyNumBlocks; i++) {
      numEntries[i] = _readNumber(indexDs);
      var firstWordSize = _readShort(indexDs);
      var firstWord = indexDs.readString(length: firstWordSize, utf8: utf8);
      var lastWordSize = _readShort(indexDs);
      var lastWord = indexDs.readString(length: lastWordSize, utf8: utf8);
      print("first: size=$firstWordSize word=$firstWord last: size=$lastWordSize word=$lastWord");
      compSize[i] = _readNumber(indexDs);
      decompSize[i] = _readNumber(indexDs);
    }
    var keyList = <Key>[];
    for (var i = 0; i < keyNumBlocks; i++) {
      var keyCompBlock = fin.readBytes(compSize[i]);
      var blockIn = _decompressBlock(keyCompBlock);
      for (var j = 0; j < numEntries[i]; j++) {
        var offset = _readNumber(blockIn);
        var word = blockIn.readString(utf8: utf8);
        if (keyList.isNotEmpty) {
          keyList[keyList.length - 1].length =
              offset - keyList[keyList.length - 1].offset;
        }
        keyList.add(Key(word, offset));
      }
      break;
    }
    return keyList;
  }

  List<Record> _readRecords(FileInputStream fin) {
    var recordNumBlocks = _readNumber(fin);
    var recordNumEntries = _readNumber(fin);
    var recordIndexLen = _readNumber(fin);
    var recordBlocksLen = _readNumber(fin);
    var recordList = <Record>[];
    for (var i = 0; i < recordNumBlocks; i++) {
      var recordBlockCompSize = _readNumber(fin);
      var recordBlockDecompSize = _readNumber(fin);
      recordList.add(Record(recordBlockCompSize, recordBlockDecompSize));
    }
    return recordList;
  }

  dynamic _readRecord(String word, int offset, int length, bool mdd) {
    var compressedOffset = 0;
    var decompressedOffset = 0;
    var compressedSize = 0;
    var decompressedSize = 0;
    for (var record in _recordList) {
      compressedSize = record.compSize;
      decompressedSize = record.decompSize;
      if ((decompressedOffset + decompressedSize) > offset) {
        break;
      }
      decompressedOffset += decompressedSize;
      compressedOffset += compressedSize;
    }
    var fin = File(path).openSync();
    fin.setPositionSync(_recordBlockOffset + compressedOffset);
    var block = fin.readSync(compressedSize);
    fin.closeSync();
    var blockIn = _decompressBlock(block);
    blockIn.skip(offset - decompressedOffset);
    if (mdd) {
      var recordBlock = blockIn.toUint8List();
      if (length > 0) {
        return recordBlock.sublist(0, length);
      } else {
        return recordBlock;
      }
    } else {
      var utf8 = _header['Encoding'] == 'UTF-8';
      return blockIn.readString(length: length, utf8: utf8);
    }
  }

  InputStream _decompressBlock(Uint8List compBlock) {
    var flag = compBlock[0];
    var data = compBlock.sublist(8);
    if (flag == 1) {
      throw new FormatException("LZO compression is not supported");
    } else if (flag == 2) {
      return BytesInputStream(Uint8List.fromList(zlib.decoder.convert(data)));
    } else {
      return BytesInputStream(data);
    }
  }

  void _decryptBlock(Uint8List key, Uint8List data, int offset) {
    var previous = 0x36;
    for (var i = 0; i < data.length - offset; i++) {
      var t = (data[i + offset] >> 4 | data[i + offset] << 4) & 0xff;
      t = t ^ previous ^ (i & 0xff) ^ key[i % key.length];
      previous = data[i + offset];
      data[i + offset] = t;
    }
  }

  Uint8List _computeKey(Uint8List data) {
    var ripemd128 = Digest('RIPEMD-128');
    ripemd128.update(data, 4, 4);
    ripemd128.update(
        Uint8List.fromList(const <int>[0x95, 0x36, 0x00, 0x00]), 0, 4);
    var key = Uint8List(16);
    ripemd128.doFinal(key, 0);
    return key;
  }

  int _readNumber(InputStream ins) {
    return _numberWidth == 8 ? ins.readUint64() : ins.readUint32();
  }

  int _readShort(InputStream ins) {
    return _numberWidth == 8 ? ins.readUint16() : ins.readByte();
  }
}
