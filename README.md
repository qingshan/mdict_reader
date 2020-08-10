# Mdict Reader

A dart library for reading mdict files. support MDX/MDD file formats.

## Usage

Read defintion from MDX:

```
dart bin/main.dart defintion [mdx_file] [query_word]
```

Parse sounds URLs from MDX:

```
dart bin/main.dart sounds [mdx_file] [query_word]
```

Read data from MDD (directly output binary to stdout):

```
dart bin/main.dart read [mdd_file] [sound_url]
```

## Acknowledge

This project was initially converted from [mdict analysis](https://bitbucket.org/xwang/mdict-analysis).
