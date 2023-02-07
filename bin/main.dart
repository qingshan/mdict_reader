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
  } else {
    words = words.expand((word) {
      if (word.endsWith('.txt')) {
        return File(word).readAsLinesSync();
      }
      return [word];
    }).toList();
  }
  if ('words' == command) {
    print(words.join("\n"));
  } else if ('sounds' == command) {
    words.where((word) => word.isNotEmpty).forEach((word) {
      var record = mdict.query(word);
      var sounds = parseSounds(record);
      sounds.forEach((sound) {
        print("$word\t$sound");
      });
    });
  } else if ('export' == command) {
    words.where((word) => word.isNotEmpty).forEach((word) {
      var file;
      if (word.startsWith('/')) {
        file = File(word.substring(1));
      } else if (word.contains('\t')) {
        var parts = word.split('\t');
        file = File(parts[0]);
        word = parts[1];
      } else {
        file = File(word + '.html');
      }
      word = word.replaceAll('/', '\\');
      if (file.existsSync()) {
        return;
      }
      file.createSync(recursive: true);
      var out = file.openWrite();
      var record = mdict.query(word);
      if (record is String) {
        out.write(record);
      } else if (record != null) {
        out.add(record);
      }
      return out.close();
    });
  } else {
    words.where((word) => word.isNotEmpty).forEach((word) {
      var record = mdict.query(word);
      if (record is String) {
        stdout.write(record);
      } else {
        stdout.add(record);
      }
    });
  }
}

List<String> parseSounds(String html) {
  var re = RegExp(' href="sound:/(\\S+)"');
  var sounds = re
      .allMatches(html)
      .map((match) => match.group(1))
      .map((sound) => sound?.replaceAll('/', '\\'))
      .whereType<String>()
      .toList();
  return sounds;
}
