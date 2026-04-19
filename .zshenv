# Sourced for ALL zsh invocations (login, interactive, scripts).
# PATH goes here (not .zshrc) so GUI-launched apps — i3, rofi, nvim opened
# from a keybinding — inherit it from the login-shell session env, not just
# from interactive terminals.

# nvm: put default node on PATH without sourcing nvm.sh (~800ms saved).
# nvm's default alias can be an exact version ("v24.12.0"), a numeric one
# ("24.12.0"), a major ("24"), or lts-style ("lts/*"). Resolve whichever
# form to the actual installed directory.
if [ -r "$HOME/.nvm/alias/default" ]; then
  _alias="$(cat "$HOME/.nvm/alias/default")"
  if   [ -d "$HOME/.nvm/versions/node/$_alias/bin" ];  then _ver="$_alias"
  elif [ -d "$HOME/.nvm/versions/node/v$_alias/bin" ]; then _ver="v$_alias"
  else _ver="$(ls "$HOME/.nvm/versions/node" 2>/dev/null | grep "^v$_alias" | sort -V | tail -1)"
  fi
  [ -n "$_ver" ] && export PATH="$HOME/.nvm/versions/node/$_ver/bin:$PATH"
  unset _alias _ver
fi
