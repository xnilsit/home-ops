# vim: ft=zsh

alias pitbull="git pull"
alias gcame="git commit --amend --no-verify"
alias gcempty='git commit --allow-empty -m "empty commit"'
alias gconflicts='git diff --name-only --diff-filter=U'
alias viconflicts='nvim $(gconflicts)'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grbs='git rebase --skip'
alias grv='git revert'
alias grvc='git revert --continue'
alias grva='git revert --abort'
alias gsadd='git submodule add'
alias gmm='git merge main'
alias gt='git tag'
alias gl='git fetch --all && git pull'
alias migrate-branch="git branch -m master main && git pull origin main && git push --set-upstream origin main"

gnb(){
  # check if branch already exists and warn user
  if git show-ref --verify --quiet refs/heads/$1; then
      echo "Branch $1 already exists, switching to it"
      git checkout $1
  else
      echo "Creating branch $1 and pushing to origin"
      git checkout -b $1
      git push --set-upstream origin $1
  fi
}

# Delete all remote tracking Git branches where the upstream branch has been deleted
alias git_prune="git fetch --prune && git branch -vv | grep 'origin/.*: gone]' | awk '{print \$1}' | xargs git branch -d"

alias ginit='git init'
alias gp='git pull && git push'
alias gch='git checkout'
alias grh='git reset --hard'
alias grf='git checkout HEAD --'
alias gchm='git checkout main'
alias git='LANG=en_US.UTF-8 git'
alias gpinit='gp --set-upstream origin main'
alias pull='git pull'
alias check='git checkout'
alias gsa='git stash apply'
alias gstash='git stash'
