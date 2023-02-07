Mdict Reader
============

A dart library for reading mdict files. support MDX/MDD file formats.

[![Pub Package](https://img.shields.io/pub/v/mdict_reader.svg)](https://pub.dev/packages/mdict_reader)

Tutorial
--------

### Using the API

Import the package:

```dart
import 'package:mdict_reader/mdict_reader.dart';
```

And call some code:

```dart
var mdict = MdictReader('example.mdx');
var record = mdict.query('hello');
stdout.write(record);
```

### Using the command-line

Read defintion from MDX file:

```shell
dart bin/main.dart defintion [mdx_file] [query_word]
```

Parse sounds URLs from MDX file:

```shell
dart bin/main.dart sounds [mdx_file] [query_word]
```

Read data from MDD file (directly output binary to stdout):

```shell
dart bin/main.dart read [mdd_file] [sound_url]
```

Misc
----

### Acknowledge

This project was initially converted from [mdict analysis](https://bitbucket.org/xwang/mdict-analysis).

### License

The MIT License, see [LICENSE](https://github.com/qingshan/mdict_reader/raw/main/LICENSE).
