
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[cyan]%}⬆"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} ✭" # ⓣ

ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[cyan]%} ✚" # ⓐ ⑃
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%} ±" # ⚡ⓜ ⑁
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} ✖" # ⓧ ⑂
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%} ➜" # ⓡ ⑄
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[red]%} ☢" # ⓤ ⑊

# More symbols to choose from:
# ☀ ✹ ☄ ♆ ♀ ♁ ♐ ♇ ♈ ♉ ♚ ♛ ♜ ♝ ♞ ♟ ♠ ♣ ⚢ ⚲ ⚳ ⚴ ⚥ ⚤ ⚦ ⚒ ⚑ ⚐ ♺ ♻ ♼ ☰ ☱ ☲ ☳ ☴ ☵ ☶ ☷
# ✡ ✔ ✖ ✚ ✱ ✤ ✦ ❤ ➜ ➟ ➼ ✂ ✎ ✐ ⨀ ⨁ ⨂ ⨍ ⨎ ⨏ ⨷ ⩚ ⩛ ⩡ ⩱ ⩲ ⩵  ⩶ ⨠ 
# ⬅ ⬆ ⬇ ⬈ ⬉ ⬊ ⬋ ⬒ ⬓ ⬔ ⬕ ⬖ ⬗ ⬘ ⬙ ⬟  ⬤ 〒 ǀ ǁ ǂ ĭ Ť Ŧ

# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
SEGMENT_SEPARATOR='⮀'

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ -n $SEGMENT_REVERSE ]]; then
    if [[ $CURRENT_BG == 'NONE' || $1 != $CURRENT_BG ]]; then
      echo -n " %{%F{$1}%}$SEGMENT_SEPARATOR%{$fg$bg%} "
    else
      echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$1
    [[ -n $3 ]] && echo -n $3
  else
    if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
      echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    else
      echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$1
    [[ -n $3 ]] && echo -n $3
  fi
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$user@%m"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local ref dirty
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(ZSH_THEME_GIT_PROMPT_CLEAN="" ZSH_THEME_GIT_PROMPT_DIRTY=1 parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git show-ref --head -s --abbrev |head -n1 2> /dev/null)"
    prompt_segment black default "%{%F{magenta}%}⭠$(git_prompt_status)$(git_prompt_ahead)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi
    echo -n "${ref/refs\/heads\//}"
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue black '%16<…<%~%<<'
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_tasks() {
  if [[ $EUID -ne 0 ]] && command -v task >/dev/null; then
    local current urgent taskcolor
    current=$(task rc.verbose=nothing rc.report.current.columns=id,description.truncated rc.report.current.filter='status:pending start.any: limit:1' rc.report.current.sort=start- current)
    urgent=$(task rc.verbose=nothing rc.report.urgent.columns=id,description.truncated rc.report.urgent.filter='status:pending limit:1' rc.report.urgent.sort=urgency-,due+,priority-,start-,project+ urgent)
    if [[ -n "$current" ]]; then
      if [[ -n "$urgent" ]]; then
	if [[ $current[(w)1] -ne $urgent[(w)1] ]]; then
	  taskcolor=yellow
	else
	  taskcolor=green
	fi
      fi
      prompt_segment $taskcolor black "%16>…>$current[(w)1] $current[(w)2,-1]%>>"
      if [[ $taskcolor = yellow ]]; then
	prompt_segment red black "%16>…>$urgent[(w)1] $urgent[(w)2,-1]%>>"
      fi
    else
      if [[ -n "$urgent" ]]; then
	prompt_segment black yellow "%16>…>$urgent[(w)1] $urgent[(w)2,-1]%>>"
      fi
    fi
  fi
}

## Main prompt
build_prompt() {
  prompt_context
  prompt_git
  prompt_dir
  prompt_end
}

## Right-hand prompt
build_rprompt() {
  RETVAL=$?
  local SEGMENT_SEPARATOR='⮂'
  local SEGMENT_REVERSE=1
  prompt_segment cyan black "%T"
  prompt_status
  prompt_tasks
  SEGMENT_SEPARATOR=''
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
RPROMPT='%{%f%b%k%}$(build_rprompt)'
