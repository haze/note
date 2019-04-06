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
  let time_str = frame.created_when.format("MM/dd/yy")
  let padded_time_str = align(time_str, 7)
  let padded_time_str_len = runeLen(padded_time_str)
  let padded_level_str = align(frame.level.to_string(), 5)
  let padded_level_str_len = runeLen(padded_level_str)
  let space_left_for_message = width - (padded_level_str_len + padded_time_str_len + 1)
  var lines = newSeq[string](1)
  if frame.time_sensitive:
    lines[0] = padded_time_str & padded_level_str & " "
  else:
    lines[0] = padded_level_str & " "
  if runeLen(frame.note) > space_left_for_message:
    # the note is too big to fit on the given space, splice in
    lines[0] = lines[0] & frame.note[0..^space_left_for_message] 
  else:
    lines[0] = lines[0] & frame.note
  for line in lines:
    stdout.write line


proc info*(message: string, time_sensitive: bool) =
  let frame = NoteFrame(
    note: message,
    level: NoteLevel.level_info,
    context: initTable[string, string](), # TODO(hazebooth): impl!
    time_sensitive: time_sensitive,
    created_when: now()
  )
  formatted_print(frame)




