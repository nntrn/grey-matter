#!/usr/bin/env bash
set -e

SCRIPT=$(realpath $0)
DIR=${SCRIPT%/*}
PAGEID=$DIR/pageid.json

if [[ -n $1 ]]; then
  DIR=$1
fi

export OUTDIR=$DIR/out
export BASE_URL='https://greysanatomy.fandom.com'

export GREY_MATTER_QUERY_URL="$BASE_URL/api.php?action=query&generator=categorymembers&formatversion=2&format=json&gcmlimit=500&gcmtitle=Category:Grey_Matter&prop=info&inprop=url"

export API_PAGEID='api.php?action=parse&formatversion=2&format=json&prop=wikitext'

get_page_ids() {
  curl -s --create-dirs -o $OUTDIR/pages.json "$GREY_MATTER_QUERY_URL"
  jq -r '.query.pages[] | select(.title|test("Category")|not) | 
      "url=\(env.BASE_URL)/\(env.API_PAGEID)&pageid=\(.pageid)\noutput=\(env.OUTDIR)/json/\(.pageid).json"
      ' $OUTDIR/pages.json >$OUTDIR/curl.txt
  cat $OUTDIR/curl.txt | curl -s -Z -K - --create-dirs

}

format_wikitext() {
  local _file=${1##*/}
  local _out

  _out="$(
    jq -r --arg i ${_file//\.*/} 'if .[$i]?  
    then (.[$i] | "\(.prefix)-\(.slug|ascii_downcase).txt")  else ""  end' $PAGEID
  )"

  if [[ -n $_out ]]; then
    jq -r '.parse.wikitext' "$1" | pandoc -f mediawiki+smart -t plain+smart -o $DIR/grey-matter/$_out
  fi
}

build() {
  wikitextj=($(ls -1 $OUTDIR/json/*.json))
  mkdir -p $DIR/grey-matter
  for i in "${wikitextj[@]}"; do
    format_wikitext $i &
  done
}

if [[ ! -f $OUTDIR/curl.txt ]]; then
  get_page_ids
fi

if [[ -f $PAGEID ]]; then
  build
  wait -n
else
  echo "Cannot locate pageid.json. Make sure it's in $_DIR/"
  exit
fi
