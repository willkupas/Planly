#!/usr/bin/env bash
# Verifica os arquivos em stage por segredos antes do commit.
# Uso: scripts/check-secrets.sh           (arquivos staged)
#      scripts/check-secrets.sh --all     (todos os arquivos rastreados)
# Imprime apenas ARQUIVO e REGRA, nunca o valor encontrado.
set -u
cd "$(git rev-parse --show-toplevel)"

if [ "${1:-}" = "--all" ]; then
  files=$(git ls-files)
else
  files=$(git diff --cached --name-only --diff-filter=ACM)
fi
[ -z "$files" ] && exit 0

fail=0
report() { echo "  BLOQUEADO: $1  ->  $2"; fail=1; }

# 1) Nomes de arquivo proibidos
name_re='(^|/)(google-services\.json|GoogleService-Info\.plist|firebase_options[^/]*\.dart|key\.properties|local\.properties|\.env(\..*)?|.*service-account.*\.json|.*firebase-adminsdk.*\.json)$|\.(jks|keystore|p12|pem|key|secret)$'
# 2) Conteúdo proibido (regex ERE)
declare -A rules=(
  ["chave de API Google (AIza...)"]='AIza[0-9A-Za-z_-]{35}'
  ["chave privada PEM"]='-----BEGIN [A-Z ]*PRIVATE KEY-----'
  ["service account JSON"]='"type"[[:space:]]*:[[:space:]]*"service_account"'
  ["private_key em JSON"]='"private_key"[[:space:]]*:'
  ["token GitHub"]='gh[pousr]_[0-9A-Za-z]{30,}'
  ["token GitHub (fine-grained)"]='github_pat_[0-9A-Za-z_]{40,}'
  ["chave AWS"]='AKIA[0-9A-Z]{16}'
  ["token Slack"]='xox[baprs]-[0-9A-Za-z-]{10,}'
  ["código OAuth Google (4/0A...)"]='4/0A[0-9A-Za-z_-]{30,}'
  ["refresh/access token Google"]='ya29\.[0-9A-Za-z_-]{30,}|1//0[0-9A-Za-z_-]{30,}'
  ["senha/segredo literal"]='(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"' ]{8,}["'"'"']'
)

while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in scripts/check-secrets.sh|.githooks/*) continue;; esac
  if echo "$f" | grep -Eiq "$name_re"; then report "$f" "nome de arquivo proibido"; continue; fi
  # ignora binários
  if ! git grep -Iq "" -- "$f" 2>/dev/null && [ "${1:-}" != "--all" ]; then :; fi
  if [ "${1:-}" = "--all" ]; then content() { cat "$f"; }; else content() { git show ":$f"; }; fi
  for name in "${!rules[@]}"; do
    if content | grep -EIq -e "${rules[$name]}"; then report "$f" "$name"; fi
  done
done <<< "$files"

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Commit abortado: possível segredo detectado. Remova/rotacione o segredo,"
  echo "adicione o arquivo ao .gitignore e tente de novo. (Falso positivo? revise antes de usar --no-verify.)"
  exit 1
fi
exit 0
