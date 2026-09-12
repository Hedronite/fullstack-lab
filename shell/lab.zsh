# hedronite-devops-lab shell layer.
# Sourced in two places:
#   - inside the container (LAB_CONTAINER=1): prompt + motd, nothing else
#   - on the host (~/.zshrc): defines the lab() function

if [[ -n "$LAB_CONTAINER" ]]; then
  setopt PROMPT_SUBST
  PROMPT='%F{214}⬢ lab%f %F{cyan}%~%f %F{green}❯%f '
  if [[ -o interactive && -r /etc/motd ]]; then
    cat /etc/motd
  fi
  return 0
fi

: "${LAB_IMAGE:=ghcr.io/hedronite/lab:latest}"
: "${LAB_WORKSPACE:=$HOME/lab-workspaces/default}"
: "${LAB_LABS:=}"
: "${LAB_TOMES:=}"

lab() {
  emulate -L zsh
  local -a run_args mounts
  local corpus_note=0
  mkdir -p "$LAB_WORKSPACE"
  mounts=(-v "$LAB_WORKSPACE:/workspace")
  if [[ -n "$LAB_LABS" && -d "$LAB_LABS" ]]; then
    mounts+=(-v "$LAB_LABS:/labs:ro")
  fi
  if [[ -n "$LAB_TOMES" && -d "$LAB_TOMES" ]]; then
    mounts+=(-v "$LAB_TOMES:/tomes:ro")
  fi
  if [[ -z "$LAB_LABS$LAB_TOMES" ]]; then
    corpus_note=1
  fi
  [[ -d "$HOME/.aws" ]]           && mounts+=(-v "$HOME/.aws:/root/.aws:ro")
  [[ -d "$HOME/.config/gcloud" ]] && mounts+=(-v "$HOME/.config/gcloud:/root/.config/gcloud:ro")
  [[ -d "$HOME/.azure" ]]         && mounts+=(-v "$HOME/.azure:/root/.azure:ro")
  [[ -d "$HOME/.kube" ]]          && mounts+=(-v "$HOME/.kube:/root/.kube:ro")
  [[ -d "$HOME/.ssh" ]]           && mounts+=(-v "$HOME/.ssh:/root/.ssh:ro")
  run_args=(--rm --hostname lab)
  if [[ -t 0 && -t 1 ]]; then
    run_args+=(-it)
  else
    run_args+=(-i)
  fi
  if (( corpus_note )); then
    echo "corpus optional: set LAB_LABS and/or LAB_TOMES to mount practice material"
  fi
  if (( $# == 0 )); then
    docker run "${run_args[@]}" "${mounts[@]}" "$LAB_IMAGE"
  else
    docker run "${run_args[@]}" "${mounts[@]}" "$LAB_IMAGE" zsh -c "${(j: :)${(q)@}}"
  fi
}
