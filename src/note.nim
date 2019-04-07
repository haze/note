import algorithm
import math, macros 
{.experimental: "forLoopMacros".}
import options
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

  b_red_color = "\e[1;91m"
  b_green_color = "\e[1;92m"
  b_yellow_color = "\e[1;93m"
  b_blue_color = "\e[1;94m"
  b_cyan_color = "\e[1;95m"

  white_color = "\e[1;97m"

type
  NoteLevel = enum
    level_info, level_warn, level_error, level_debug

type
  NoteFrame = object
    note: string
    level: NoteLevel
    context: Table[string, string]
    time_sensitive: bool
    created_when: DateTime

type
  Pad* = seq[NoteFrame]

proc last_used_level(pad: Pad): Option[NoteLevel] =
  if pad.len > 0:
    result = some(pad[^1].level)

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

proc message_color(level: NoteLevel): string =
  case level:
  of level_info:
    result = b_green_color
  of level_warn:
    result = b_yellow_color
  of level_error:
    result = b_red_color
  of level_debug:
    result = b_blue_color


proc to_strings(level: NoteLevel): (string, string) =
  ## returns (uncolored, colored) strings representing the level
  var identifier: string = "?"
  case level:
  of level_info:
    identifier = "I"
  of level_warn:
    identifier = "W"
  of level_error:
    identifier = "E"
  of level_debug:
    identifier = "#"
  result = ("[" & identifier & "]", "[" & colorize(identifier, level.message_color) & "]")

proc print_time(buffer: var string, frame: NoteFrame): int =
  result = 0
  if frame.time_sensitive:
    let text = frame.created_when.format(" H:mm MMM dd ")
    let text_len = runeLen(text)
    buffer &= colorize(text, white_color)
    result += text_len

proc print_level(buffer: var string, pad: Pad, frame: NoteFrame, offset: int): int =
  result = offset  
  var should_print = true
  var level_str_colorized = ""
  try:
    should_print = pad.last_used_level.get() != frame.level
  except UnpackError:
    discard

  if should_print:
    let (level_str, new_level_str_colorized) = frame.level.to_strings
    let level_str_len = runeLen(level_str)
    result += level_str_len
    level_str_colorized = new_level_str_colorized
  else:
    # print continuation
    result += 3 # runeLen("[|]")
    level_str_colorized = "[" & colorize("|", frame.level.message_color) & "]"
  buffer &= level_str_colorized

proc print_multiline(buffer: var string, note: string, offset, width: int): int =
  result = runeLen(note)
  let
    space_left = width - offset - 1
    text_for_first_line = note[..(space_left-2)]
    rest_to_print = chunk(note[space_left-1..^1], space_left)
    spacer = repeat(" ", offset - 3) & "..."
  buffer &= " " & text_for_first_line & "\n"
  
  for index, line in enumerate(rest_to_print):
    buffer &= spacer
    if line[0] == ' ':
      buffer &= line[1..^1] & " "
    else:
      buffer &= line
    if index != rest_to_print.len - 1:
      buffer &= "\n"

proc context_width(context: Table[string, string]): int =
  result = 0
  var pairs = toSeq(context.pairs).reversed
  let pair_len = pairs.len
  for index, pair in enumerate(pairs):
    let (key, value) = pair
    var format = "$# = $#"
    if index != pair_len - 1:
      format &= ", "
    let printed = format % [key, value]
    result += runeLen(printed)

proc print_single_line_context(buffer: var string, context: Table[string, string], level: NoteLevel) =
  let pairs = toSeq(context.pairs).reversed
  let pair_len = pairs.len
  buffer &= " "
  for index, pair in enumerate(pairs):
    let (key, value) = pair
    var format = "$# = $#"
    if index != pair_len - 1:
      format &= ", "
    let printed = format % [colorize($key, level.message_color), colorize($value, white_color)]
    buffer &= printed

proc print_note(buffer: var string, frame: NoteFrame, offset, width: int): int =
  result = offset
  let
    note = frame.note
    note_len = runeLen(note)

  if note_len + offset > width:
    result = print_multiline(buffer, note, offset, width) # can reset offset
  else:
    buffer &= " " & note
    let context_width = context_width frame.context
    if context_width + offset + 1 <= width:
      result += context_width
      print_single_line_context(buffer, frame.context, frame.level)

proc formatted_print(pad: Pad, frame: NoteFrame) =
  # 1 - print time or not
  # 2 - print message level if new
  # 3 - print message
  var buffer = ""
  var offset = print_time(buffer, frame)
  let width = terminalWidth()
  offset = print_level(buffer, pad, frame, offset)
  offset = print_note(buffer, frame, offset, width)

  buffer &= "\n"
  stdout.write buffer
  #let context_offset, printed_context = print_context frame.context, offset
  #offset = context_offset
  #if not printed_context:
  #  echo "tbi"


proc easy_frame(message: string, 
  time_sensitive: bool, level: NoteLevel,
  context: Table[string, string]): NoteFrame =
  result = NoteFrame(
    note: message,
    level: level,
    context: context,
    time_sensitive: time_sensitive,
    created_when: now()
  )


proc info*(pad: var Pad, message: string, context: openArray[(string, string)] = [],
  time_sensitive: bool = true) =
  let frame = easy_frame(message, time_sensitive, NoteLevel.level_info, context.toTable)
  pad.formatted_print frame
  pad.add frame

proc warn*(pad: var Pad, message: string, context: openArray[(string, string)] = [],
  time_sensitive: bool = true) =
  let frame = easy_frame(message, time_sensitive, NoteLevel.level_warn, context.toTable)
  pad.formatted_print frame
  pad.add frame

proc error*(pad: var Pad, message: string, context: openArray[(string, string)] = [],
  time_sensitive: bool = true) =
  let frame = easy_frame(message, time_sensitive, NoteLevel.level_error, context.toTable)
  pad.formatted_print frame
  pad.add frame

proc debug*(pad: var Pad, message: string, context: openArray[(string, string)] = [],
  time_sensitive: bool = true) =
  let frame = easy_frame(message, time_sensitive, NoteLevel.level_debug, context.toTable)
  pad.formatted_print frame
  pad.add frame


