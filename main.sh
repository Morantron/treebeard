#!/usr/bin/env bash

function tree__init() {
  echo ""
}

function tree__get_parent_at() {
  local tree="$1"
  local cursor="$2"
  local current_indent=$(__indent_at "$tree" $cursor)
  local parent_indent=$((current_indent - 2))

  while [[ ! "$current_indent" == "$parent_indent" ]] && [[ "$cursor" -gt 0 ]]
  do
    cursor=$((cursor - 1))
    current_indent=$(__indent_at "$tree" $cursor)
  done

  echo "$cursor"
}

function tree__get_children_at() {
  local tree="$1"
  local cursor="$2"
  local strategy="$3"

  local current_indent=$(__indent_at "$tree" $cursor)
  local children_indent=$((current_indent + 2))
  local tree_size=$(echo -e "$tree" | wc -l)
  local found_children=""

  cursor=$((cursor + 1))
  current_indent=$(__indent_at "$tree" $cursor)

  while [[ "$current_indent" -ge "$children_indent" ]] && [[ "$cursor" -le "$tree_size" ]]
  do
    if [[ $strategy == "all_descendants" ]] && [[ "$current_indent" -ge "$children_indent" ]]; then
      found_children="$found_children $cursor"
    elif [[ "$current_indent" == "$children_indent" ]]; then
      found_children="$found_children $cursor"
    fi

    cursor=$((cursor + 1))
    current_indent=$(__indent_at "$tree" $cursor)
  done

  echo "$found_children" | sed "s/^ *//g"
}

function tree__visit_depth() {
  local tree="$1"
  local visit="$2"
  local acc_cursor=$3
  local acc_child_index=$4
  local acc_depth=$5

  local child_index=""
  local node=""

  acc_cursor=${acc_cursor:=1}
  acc_child_index=${acc_child_index:=1}
  acc_depth=${acc_depth:=1}

  node=$(tree__read_node_at "$tree" "$acc_cursor")

  $visit "$node" "$acc_cursor" "$acc_child_index" "$(tree__is_leaf_at "$tree" "$acc_cursor")" "$acc_depth"

  child_index=1

  for child_cursor in $(tree__get_children_at "$tree" "$acc_cursor"); do
    tree__visit_depth "$tree" $visit "$child_cursor" "$child_index" "$((acc_depth + 1))"
    child_index=$((child_index + 1))
  done
}

function tree__is_leaf_at() {
  local tree="$1"
  local cursor=$2

  if [[ "$(tree__get_children_at "$tree" "$cursor")" == "" ]]; then
    echo 1
  else
    echo 0
  fi
}

function tree__append_at() {
  local tree="$1"
  local cursor=$2
  local node=$3
  local children_indent="$(($(__indent_at "$tree" $cursor) + 2))"
  local last_children_cursor=$(tree__get_children_at "$tree" $cursor | grep -Eo "[0-9]+$")
  local target_cursor=""

  if [[ "$cursor" == "0" ]]; then
    target_cursor="0"
    children_indent=""
  elif [[ ! $last_children_cursor == "" ]]; then
    target_cursor=$last_children_cursor
  else
    target_cursor=$cursor
  fi

  echo "$(__insert_line_after "$tree" "$target_cursor" "$node" "$children_indent")"
}

function tree__read_node_at() {
  local tree="$1"
  local cursor=$2
  local strategy="$3"

  local children_cursor=""

  if [[ $strategy == "all_descendants" ]] ; then
    children_cursor=$(tree__get_children_at "$tree" $cursor "all_descendants")
  fi

  local lines_sed="$(echo "$cursor $children_cursor" | sed "s/^ *//" | sed "s/ *$//" | sed "s/  */p;/g")p"
  local lines=$(echo -e "$tree" | sed -n "$lines_sed")
  local node_indent=$(__indent_at "$tree" $cursor)
  local remove_indent_sed="s/^$(__repeat_char " " $node_indent)//"

  echo -e "$lines" | sed "$remove_indent_sed"
}

# text operations

function __indent_at() {
  local tree="$1"
  local cursor=$2

  if [[ "$cursor" == 0 ]]; then
    echo 0
  else
    local line=$(echo -e "$tree" | sed -n "${cursor}p")
    local indent=$(echo "$line" | grep -o "^ *")
    echo ${#indent}
  fi
}

function __delete_line_at() {
  local tree="$1"
  local cursor="$2"
  local sed_cmd=$(echo $cursor | sed "s/[0-9]*/&d/g" |sed "s/,/;/g")

  echo -e "$tree" | sed -e "$sed_cmd"
}

function __repeat_char() {
  local char="$1"
  local times="$2"

  echo -e "$(seq -s "$char" 1 $((times + 1)) | tr -d "[[:digit:]]")"
}

function __insert_line_after() {
  local tree="$1"
  local cursor="$2"
  local text="$3"
  local indent="$4"
  local indent_sed="$(__repeat_char " " "${indent:=0}" | sed "s/ /\\\\ /g")"
  local last_line_padding=""

  OLDIFS=$IFS
  IFS=$'\n'
  for line in $(echo -e "$text"); do
    if [[ $(echo "$tree" | wc -l) == "$cursor" ]]; then
      last_line_padding="\n"
    else
      last_line_padding=""
    fi


    tree="$(echo -e "$tree$last_line_padding" | sed "$((cursor + 1))i$indent_sed$line")\n"

    cursor=$((cursor + 1))
  done
  IFS=$OLDIFS

  echo -e "$tree"
}

function __prepend_indent() {
  local indent="$1"
  local text="$2"

  echo "$(__repeat_char " " "$indent")$text"
}
