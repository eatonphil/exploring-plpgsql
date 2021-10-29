set -eux

sudo -u postgres psql -c "$(printf "%s;\n%s" "$(cat $1)" "$2")"
