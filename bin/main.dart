import 'dart:io';
import 'package:args/args.dart';
import 'package:mdict_reader/mdict_reader.dart';

void main(List<String> args) {
  var parser = ArgParser();
  var results = parser.parse(args);
  var command = results.rest[0];
  var path = results.rest[1];
  var words = results.rest.sublist(2);
  var mdict = MdictReader(path);
  if (words.isEmpty) {
    words = mdict.keys();
  }
  words = words.expand((word) {
    if (word.endsWith('.txt')) {
      return File(word).readAsLinesSync();
    } else {
      return [word];
    }
  }).toList();
  words.where((word) => word.isNotEmpty).forEach((word) {
    var record = mdict.query(word);
    if ('sounds' == command) {
      var sounds = parseSounds(record);
      print('${word}\t${sounds.join(",")}');
    } else {
      if (record is String) {
        stdout.write(record);
      } else {
        stdout.add(record);
      }
    }
  });
}

Function processor(String command) {
  if ('sounds' == command) {
    return (String word, dynamic record) {
      var sounds = parseSounds(record);
      print('${word}\t${sounds.join(",")}');
    };
  }
  return (String word, dynamic record) {
    if (record is String) {
      stdout.write(record);
    } else {
      stdout.add(record);
    }
  };
}

List<String> parseSounds(String html) {
  var re = RegExp(' href="sound:/(\\S+)"');
  var sounds = re
      .allMatches(html)
      .map((match) => match.group(1))
      .map((sound) => sound.replaceAll('/', '\\'))
      .toList();
  return sounds;
}
