import math, macros 
{.experimental: "forLoopMacros".}
import queues
import strutils, sequtils
import tables, terminal, times
import unicode


const
  reset_color = "\e[0m"
  red_color = "\e[1;31m"
  green_color = "\e[1;32m"
  yellow_color = "\e[1;33m"
  blue_color = "\e[1;34m"
  cyan_color = "\e[1;36m"
  white_color = "\e[1;97m"

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

macro enumerate(x: ForLoopStmt): untyped =
  expectKind x, nnkForStmt
  # we strip off the first for loop variable and use
  # it as an integer counter:
  result = newStmtList()
  result.add newVarStmt(x[0], newLit(0))
  var body = x[^1]
  if body.kind != nnkStmtList:
    body = newTree(nnkStmtList, body)
  body.add newCall(bindSym"inc", x[0])
  var newFor = newTree(nnkForStmt)
  for i in 1..x.len-3:
    newFor.add x[i]
  # transform enumerate(X) to 'X'
  newFor.add x[^2][1]
  newFor.add body
  result.add newFor

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

proc colorize(thing: string, color: string): string = 
  result = color & thing & reset_color

proc to_strings(level: NoteLevel): (string, string) =
  case level:
  of level_info:
    let name = " INFO"
    result = (name, colorize(name, green_color))  
  of level_warn:
    let name = " WARN"
    result = (name, colorize(name, yellow_color))
  of level_error:
    let name = "ERROR"
    result = (name, colorize(name, red_color))
  of level_debug:
    let name = "DEBUG"
    result = (name, colorize(name, cyan_color))

proc write_context(context: Table[string, string], offset, width: int) =
  let spacer = repeat(' ', offset)
  let pairs = toSeq(context.pairs())
  var mut_offset = offset
  var new_line, first_run = true
  for index, pair in enumerate(pairs):
    let (key, value) = pair
    let is_last = index == pairs.len - 1
    let colored_obj = colorize("$#", green_color)
    var format = colored_obj & colorize(" = ", white_color) & colored_obj
    var uncolored_format = "$# = $#"
    if not is_last:
      format &= ", "
      uncolored_format &= ", "
    let written = format % [key, value]
    let written_len = runeLen(uncolored_format % [key, value])
    if mut_offset + written_len > width:
      new_line = true
      mut_offset = offset
    if new_line:
      if not first_run:
        stdout.write "\n"
      else:
        first_run = false
      stdout.write spacer
      new_line = false
    stdout.write written
    mut_offset += written_len
  stdout.write "\n"

proc formatted_print(frame: NoteFrame) =
  let width = terminalWidth()
  let note_width = runeLen(frame.note)
  # base line
  # time sens: " 8/4/11  INFO message loel "
  let (level_str, level_str_colored) = frame.level.to_strings()
  let 
    level_str_len = runeLen(level_str)
    hour_str = unicode.align(frame.created_when.format("H"), 2)
    middle_time_str = frame.created_when.format(":mm MMM d")
    time_str = hour_str & middle_time_str & " "
    expected_time_str_len = runeLen(time_str)
    padded_time_str = unicode.align(time_str, expected_time_str_len)
    padded_time_str_len = runeLen(padded_time_str)
    space_left_for_message = width - (level_str_len + padded_time_str_len)
  var lines = newSeq[string](1)
  let main_offset = runeLen(padded_time_str)
  if frame.time_sensitive:
    lines[0] = padded_time_str & level_str_colored & " "
  else:
    let anticipated_str = level_str_colored & " "
    let anticipated_size = runeLen(anticipated_str)
    lines[0] = unicode.align(anticipated_str, expected_time_str_len + anticipated_size)

  if runeLen(frame.note) > space_left_for_message:
    # the note is too big to fit on the given space, splice in
    let space_aware_space_left = space_left_for_message - 2
    lines[0] = lines[0] & white_color & frame.note[0..space_aware_space_left] & reset_color
    # append the rest
    let rest = frame.note[space_aware_space_left..^1]
    let appending_format_line = repeat(' ', main_offset - 3) & "..."
    for piece in chunk(rest, space_aware_space_left + level_str_len + 2):
      lines.add(white_color & appending_format_line & piece & reset_color)
  else:
    lines[0] = lines[0] & white_color & frame.note & reset_color
  for line in lines:
    stdout.write line
  stdout.write "\n"
  write_context frame.context, main_offset, width
  flushFile stdout


proc easy_frame(message: string, 
  time_sensitive: bool, level: NoteLevel,
  context: Table[string, string]): NoteFrame =
  result = NoteFrame(
    note: message,
    level: level,
    context: context, # TODO(hazebooth): impl!
    time_sensitive: time_sensitive,
    created_when: now()
  )

proc info*(message: string, 
  time_sensitive: bool = true, context: Table[string, string]) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_info, context))

proc warn*(message: string, 
  time_sensitive: bool = true, context: Table[string, string]) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_warn, context))

proc error*(message: string, 
  time_sensitive: bool = true, context: Table[string, string]) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_error, context))

proc debug*(message: string, 
  time_sensitive: bool = true, context: Table[string, string]) =
  formatted_print(easy_frame(message, time_sensitive, NoteLevel.level_debug, context))


