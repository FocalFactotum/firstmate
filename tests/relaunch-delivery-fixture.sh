#!/usr/bin/env bash

fm_fixture_delivered_brief() { # <emitted-launch-command> <destination> <encoder>
  python3 - "$1" "$2" "$3" <<'PY'
import pathlib
import re
import shlex
import subprocess
import sys

command, destination, encoder = sys.argv[1:]
if command.startswith(". '") and command.endswith("'"):
    command = pathlib.Path(command[3:-1]).read_text()
if 'encode launch-brief' not in command and 'Firstmate operational input waiting: read' not in command:
    sys.exit(1)
parts = shlex.split(command)
if '/bin/sh' in parts:
    shell = parts.index('/bin/sh')
    if parts[shell + 1:shell + 2] == ['-c']:
        command = parts[shell + 2]
pattern = re.compile(r'"\$\(([^\n]*? encode launch-brief < [^\n]*?)\)"')

def expand(match):
    global encoder
    parts = shlex.split(match[1])
    if len(parts) != 5 or parts[1:4] != ['encode', 'launch-brief', '<']:
        raise ValueError('invalid launch envelope command')
    encoder = parts[0]
    with open(parts[4], 'rb') as body:
        envelope = subprocess.check_output(parts[:3], stdin=body).decode()
    return shlex.quote(envelope)

command = pattern.sub(expand, command)
for argument in shlex.split(command):
    if argument.startswith(": Firstmate operational input waiting: read '"):
        record = argument[len(": Firstmate operational input waiting: read '"):]
        record = record[:-len("' and handle its contents as Firstmate operational input.")]
        envelope = pathlib.Path(record).read_bytes()
        break
    if 'FIRSTMATE_OP: v1 launch-brief' in argument:
        envelope = argument.encode()
        break
else:
    sys.exit(1)
body = subprocess.check_output([encoder, 'body'], input=envelope)
pathlib.Path(destination).write_bytes(body)
PY
}
