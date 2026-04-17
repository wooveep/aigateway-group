#!/usr/bin/env bash

dev_stage() {
  echo "[$1] $2"
}

dev_info() {
  echo "[INFO] $*"
}

dev_warn() {
  echo "[WARN] $*" >&2
}

dev_die() {
  echo "[ERROR] $*" >&2
  exit 1
}

dev_need_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || dev_die "Missing required command: ${cmd}"
}

dev_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

yaml_render_scalar() {
  local value="$1"
  local lower escaped

  if [[ -z "${value}" ]]; then
    printf '""\n'
    return 0
  fi

  lower="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${lower}" =~ ^(null|true|false|yes|no|on|off|~)$ ]] || [[ "${value}" =~ ^[0-9] ]]; then
    escaped="${value//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    printf '"%s"\n' "${escaped}"
    return 0
  fi

  if [[ "${value}" =~ ^[A-Za-z_./-][A-Za-z0-9_./:-]*$ ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  escaped="${value//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '"%s"\n' "${escaped}"
}

yaml_get_scalar() {
  local file="$1"
  local path="$2"
  local default_value="${3:-}"

  [[ -f "${file}" ]] || {
    printf '%s\n' "${default_value}"
    return 0
  }

  awk -v target="${path}" -v default_value="${default_value}" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^'\''.*'\''$/) {
        s = substr(s, 2, length(s) - 2)
      }
      return s
    }
    function build_path(level,    i, out) {
      out = ""
      for (i = 0; i <= level; ++i) {
        if (keys[i] == "") {
          continue
        }
        out = (out == "" ? keys[i] : out "." keys[i])
      }
      return out
    }
    BEGIN {
      max_level = 0
      found = 0
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
      next
    }
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      trimmed = line
      sub(/^[ ]*/, "", trimmed)
      if (trimmed !~ /^[^:#-][^:]*:/) {
        next
      }

      indent = length(line) - length(trimmed)
      level = int(indent / 2)
      colon = index(trimmed, ":")
      key = unquote(trim(substr(trimmed, 1, colon - 1)))
      value = trim(substr(trimmed, colon + 1))

      keys[level] = key
      for (i = level + 1; i <= max_level + 8; ++i) {
        delete keys[i]
      }
      if (level > max_level) {
        max_level = level
      }

      current = build_path(level)
      if (current == target && value != "") {
        print unquote(value)
        found = 1
        exit 0
      }
    }
    END {
      if (!found) {
        print default_value
      }
    }
  ' "${file}"
}

yaml_get_list() {
  local file="$1"
  local path="$2"

  [[ -f "${file}" ]] || return 0

  awk -v target="${path}" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^'\''.*'\''$/) {
        s = substr(s, 2, length(s) - 2)
      }
      return s
    }
    function build_path(level,    i, out) {
      out = ""
      for (i = 0; i <= level; ++i) {
        if (keys[i] == "") {
          continue
        }
        out = (out == "" ? keys[i] : out "." keys[i])
      }
      return out
    }
    BEGIN {
      max_level = 0
      in_block = 0
      block_indent = -1
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
      next
    }
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      trimmed = line
      sub(/^[ ]*/, "", trimmed)

      if (trimmed ~ /^[^:#-][^:]*:/) {
        indent = length(line) - length(trimmed)
        level = int(indent / 2)
        colon = index(trimmed, ":")
        key = trim(substr(trimmed, 1, colon - 1))
        value = trim(substr(trimmed, colon + 1))

        if (in_block && indent <= block_indent) {
          exit 0
        }

        keys[level] = key
        for (i = level + 1; i <= max_level + 8; ++i) {
          delete keys[i]
        }
        if (level > max_level) {
          max_level = level
        }

        current = build_path(level)
        if (current == target && value == "") {
          in_block = 1
          block_indent = indent
        }
        next
      }

      if (!in_block) {
        next
      }

      if (trimmed ~ /^-[ ]*/) {
        indent = length(line) - length(trimmed)
        if (indent > block_indent) {
          value = trimmed
          sub(/^-[ ]*/, "", value)
          print unquote(value)
          next
        }
      }

      if (trimmed ~ /^[^:#-][^:]*:/) {
        indent = length(line) - length(trimmed)
        if (indent <= block_indent) {
          exit 0
        }
      }
    }
  ' "${file}"
}

yaml_get_map_pairs() {
  local file="$1"
  local path="$2"

  [[ -f "${file}" ]] || return 0

  awk -v target="${path}" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^'\''.*'\''$/) {
        s = substr(s, 2, length(s) - 2)
      }
      return s
    }
    function build_path(level,    i, out) {
      out = ""
      for (i = 0; i <= level; ++i) {
        if (keys[i] == "") {
          continue
        }
        out = (out == "" ? keys[i] : out "." keys[i])
      }
      return out
    }
    BEGIN {
      max_level = 0
      in_block = 0
      block_indent = -1
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
      next
    }
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      trimmed = line
      sub(/^[ ]*/, "", trimmed)
      if (trimmed !~ /^[^:#-][^:]*:/) {
        next
      }

      indent = length(line) - length(trimmed)
      level = int(indent / 2)
      colon = index(trimmed, ":")
      key = unquote(trim(substr(trimmed, 1, colon - 1)))
      value = trim(substr(trimmed, colon + 1))

      if (in_block && indent <= block_indent) {
        exit 0
      }

      keys[level] = key
      for (i = level + 1; i <= max_level + 8; ++i) {
        delete keys[i]
      }
      if (level > max_level) {
        max_level = level
      }

      current = build_path(level)
      if (current == target && value == "") {
        in_block = 1
        block_indent = indent
        next
      }

      if (in_block && indent == block_indent + 2 && value != "") {
        print key "=" unquote(value)
      }
    }
  ' "${file}"
}

yaml_get_scalar_from_files() {
  local path="$1"
  shift

  local value=""
  local current=""
  local file

  for file in "$@"; do
    current="$(yaml_get_scalar "${file}" "${path}")"
    if [[ -n "${current}" ]]; then
      value="${current}"
    fi
  done

  printf '%s\n' "${value}"
}

yaml_set_scalar() {
  local file="$1"
  local path="$2"
  local value="$3"
  local rendered tmp rc

  [[ -f "${file}" ]] || dev_die "YAML file not found: ${file}"

  rendered="$(yaml_render_scalar "${value}")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/yaml-set.XXXXXX")"

  if ! awk -v target="${path}" -v rendered="${rendered}" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function build_path(level,    i, out) {
      out = ""
      for (i = 0; i <= level; ++i) {
        if (keys[i] == "") {
          continue
        }
        out = (out == "" ? keys[i] : out "." keys[i])
      }
      return out
    }
    BEGIN {
      max_level = 0
      changed = 0
    }
    {
      line = $0
      trimmed = line
      sub(/^[ ]*/, "", trimmed)
      if (trimmed ~ /^[^:#-][^:]*:/) {
        indent = length(line) - length(trimmed)
        level = int(indent / 2)
        colon = index(trimmed, ":")
        key = trim(substr(trimmed, 1, colon - 1))

        keys[level] = key
        for (i = level + 1; i <= max_level + 8; ++i) {
          delete keys[i]
        }
        if (level > max_level) {
          max_level = level
        }

        current = build_path(level)
        if (current == target) {
          print substr(line, 1, indent) key ": " rendered
          changed = 1
          next
        }
      }

      print
    }
    END {
      if (!changed) {
        exit 3
      }
    }
  ' "${file}" > "${tmp}"; then
    rc=$?
    rm -f "${tmp}"
    if [[ ${rc} -eq 3 ]]; then
      dev_die "YAML path not found: ${path} (${file})"
    fi
    dev_die "Failed to update YAML file: ${file}"
  fi

  mv "${tmp}" "${file}"
}

csv_contains() {
  local csv="$1"
  local item="$2"
  [[ ",${csv}," == *",${item},"* ]]
}

default_dev_stamp() {
  date '+%Y%m%d%H%M%S'
}

stamp_dev_tag() {
  local current_tag="$1"
  local stamp="$2"

  if [[ "${current_tag}" =~ ^(.*)-dev-[0-9]{14}$ ]]; then
    printf '%s-dev-%s\n' "${BASH_REMATCH[1]}" "${stamp}"
    return 0
  fi

  if [[ "${current_tag}" =~ ^dev-[0-9]{14}$ ]]; then
    printf 'dev-%s\n' "${stamp}"
    return 0
  fi

  printf '%s-dev-%s\n' "${current_tag}" "${stamp}"
}
