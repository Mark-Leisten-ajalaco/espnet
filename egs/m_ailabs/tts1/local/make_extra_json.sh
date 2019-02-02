#!/bin/bash

# Copyright 2018 Nagoya University (Tomoki Hayashi)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

dict=
nlsyms=
feats_scp=
spk_xvector_scp=
spks="eva elizabeth karen lisa"

. utils/parse_options.sh

if [ ! $# -eq 2 ]; then
   echo "Usage: $0 --dict <dict> --nlsyms <nlsyms> --feats_scp <feats.scp> \\"
   echo "   --spk_xvector_scp <spk_xvector.scp> --spks \"eva elizabeth karen lisa\" \\"
   echo "   <data-dir> <dump-dir>"
   exit 1;
fi

set -euo pipefail

datadir=$1
dumpdir=$2

[ ! -e ${dumpdir} ] && mkdir -p ${dumpdir}
[ -e ${dumpdir}/wav.scp ] && rm ${dumpdir}/wav.scp
[ -e ${dumpdir}/utt2spk ] && rm ${dumpdir}/utt2spk
[ -e ${dumpdir}/text ] && rm ${dumpdir}/text

for spk in $(echo ${spks} | sort); do
    cat ${datadir}/text | \
        awk -v s=${spk} '{printf "%s_",s; for(i=1;i<NF;++i){printf("%s ",$i)}print $NF}' | \
        sort >> ${dumpdir}/text
    cat ${feats_scp} | \
        awk -v s=${spk} '{printf "%s_",s; for(i=1;i<NF;++i){printf("%s ",$i)}print $NF}' | \
        sort >> ${dumpdir}/feats.scp
    cat ${datadir}/utt2spk | \
        awk -v s=${spk} '{printf "%s_%s %s\n",s,$1,s}' | \
        sort >> ${dumpdir}/utt2spk
done

# store into dicts
declare -A dict
while read -r line; do
    spkid=$(echo $line | cut -d " " -f 1)
    path=$(echo $line | cut -d " " -f 2)
    dict[${spkid}]=${path}
done < <(cat ${spk_xvector_scp})

# make spk embedding scp for each uttid
[ -e ${dumpdir}/xvector.scp ] && rm ${dumpdir}/xvector.scp
xvector_scp=${dumpdir}/xvector.scp
while read -r line;do
    uttid=$(echo ${line} | cut -d " " -f 1)
    spkid=$(echo ${line} | cut -d "_" -f 1)
    echo "${uttid} ${dict[${spkid}]}" >> ${xvector_scp}
done < <(cat $dumpdir/text)

# convert to json
data2json.sh \
    --feat ${dumpdir}/feats.scp \
    --nlsyms ${nlsyms} \
    ${dumpdir} ${dict} > ${dumpdir}/data.json

# add xvector info to json
local/update_json.sh \
    ${dumpdir}/data.json ${dumpdir}/xvector.scp
