import math
import queues
import strutils
import tables, terminal, times
import unicode


const
  reset_color = "\e[0m"
  red_color = "\e[1;31m"
  green_color = "\e[1;32m"
  yellow_color = "\e[1;33m"
  blue_color = "\e[1;34m"
  magenta_color = "\e[1;35m"
  cyan_color = "\e[1;36m"
  white_color = "\e[1;37m"

type
  NoteLevel = enum
    level_info, level_warn, level_error, level_debug
    # info + warn = potentially user facing
    # error = user facing + abort
    # debug = developer facing, 
    # automatically purged in production TODO(hazebooth)

type
  NoteFrame = object
    note: string
    level: NoteLevel
    context: Table[string, string]
    time_sensitive: bool
    created_when: DateTime

proc rune_skip(source: string, n: int): string =
  ## skips n runes in a string
  result = $ (toRunes(source)[n..^1])

proc chunk(source: string, size: int): seq[string] =
  let og_rune_count = runeLen(source)
  let expected = int(ceil(og_rune_count / size))
  result = newSeq[string](expected)
  var rune_queue = initQueue[Rune]()
  for rune in toRunes(source):
    rune_queue.add(rune)
  var bucket = newSeq[Rune](0)
  var index = 0
  while rune_queue.len > 0:
    while bucket.len < size and rune_queue.len > 0:
      let rune = rune_queue.pop()
      bucket.add(rune)
    result[index] = join(bucket)
    index += 1
    bucket = newSeq[Rune](0)
  assert result.len == expected

proc to_string(level: NoteLevel): string =
  case level:
  of level_info:
    result = "info"
  of level_warn:
    result = "warn"
  of level_error:
    result = "error"
  of level_debug:
    result = "debug"

proc formatted_print(frame: NoteFrame) =
  let width = terminalWidth()
  let note_width = runeLen(frame.note)
  # base line
  # time sens: " 8/4/11  INFO message loel "
  let 
    hour_str = strutils.align(frame.created_when.format("H"), 2)
    middle_time_str = frame.created_when.format(":mm MMM d")
    time_str = hour_str & middle_time_str
    expected_time_str_len = runeLen(time_str) + 1
    padded_time_str = strutils.align(time_str, expected_time_str_len)
    padded_time_str_len = runeLen(padded_time_str)
    padded_level_str = strutils.align(frame.level.to_string(), 6)
    padded_level_str_len = runeLen(padded_level_str)
    space_left_for_message = width - (padded_level_str_len + padded_time_str_len + 1)
  var lines = newSeq[string](1)
  if frame.time_sensitive:
    lines[0] = padded_time_str & padded_level_str & " "
  else:
    let anticipated_str = padded_level_str & " "
    let anticipated_size = runeLen(anticipated_str)
    lines[0] = strutils.align(anticipated_str, expected_time_str_len + anticipated_size)

  if runeLen(frame.note) > space_left_for_message:
    # the note is too big to fit on the given space, splice in
    let space_aware_space_left = space_left_for_message - 1
    lines[0] = lines[0] & frame.note[0..space_aware_space_left]
    # append the rest
    let rest = frame.note[space_aware_space_left..^1]
    let appending_format_line = repeat(' ', expected_time_str_len - 2) & "..."
    for piece in chunk(rest, space_aware_space_left + padded_level_str_len + 1):
      lines.add(appending_format_line & piece)
  else:
    lines[0] = lines[0] & frame.note
  for line in lines:
    stdout.write line
  stdout.write "\n"
  flushFile(stdout)


proc easy_frame(message: string, time_sensitive: bool, level: NoteLevel): NoteFrame =
  result = NoteFrame(
    note: message,
    level: level,
    context: initTable[string, string](), # TODO(hazebooth): impl!
    time_sensitive: time_sensitive,
    created_when: now()
  )

proc info*(message: string, time_sensitive: bool = true) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_info))

proc warn*(message: string, time_sensitive: bool = true) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_warn))

proc error*(message: string, time_sensitive: bool = true) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_error))

proc debug*(message: string, time_sensitive: bool = true) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_debug))



