#!/bin/bash

# correr setup
bash setup.sh

# path de conda
CONDA_BASE=$(conda info --base 2>/dev/null)

# verificar conda y cargar ambientes
source "$CONDA_BASE"/bin/activate cnv_discovery

# cargar env de telegram
source .env

# eliminar datos de análisis anteriores
[ -d depths ] && rm -r depths
[ -d sublists ] && rm -r sublists

# rutas a archivos necesarios
ref_ex="run_files/intervals-Broad.human.exome.b37.list"
patients="run_files/patients.list"
fasta="/mnt/HG_37/human_g1k_v37.fasta"
params="run_files/params.txt"

# cantidad de pacientes por lista
frag_len=$1

# directorio para las sublistas de pacientes
mkdir sublists
mkdir -p depths/depths_fixed/data

# dividir la lista original en la carpeta sublists
split -d -l $frag_len $patients sublists/patients_

# agregar sufijo para análisis posteriores 
while IFS= read -r line; do
	mv $line sublists/"$(basename $line).list"
done < <(find sublists -name "patients*")

# activar entorno de conda con gatk
#source /mnt/anaconda3/bin/activate gatk

# por cada sublista extraer el índice y aplicar DepthOfCoverage de forma paralela
while IFS= read -r line; do
	number=$(echo "$(basename $line)" | awk -F'.' '{print $1}' | awk -F'_' '{print $2}')
	gatk DepthOfCoverage -I $line -L $ref_ex -R $fasta --omit-depth-output-at-each-base --omit-locus-table --min-base-quality 0 --start 1 --stop 5000 --nBins 200 --include-ref-n-sites --count-type COUNT_READS -O ./depths/group${number}.DATA &
done < <(find sublists -type f -name "patients*")

wait

# corregir formato de las tablas
for i in $(find depths -maxdepth 1 -mindepth 1 -name "*.DATA.sample_interval_summary"); do 
	sed 's/,/\t/g' $i > depths/depths_fixed/"$(basename $i)"
done

if [[ -z "$(find depths/depths_fixed -maxdepth 1 -name '*.DATA.sample_interval_summary' -empty)" && "$(find depths/depths_fixed -maxdepth 1 -name '*.DATA.sample_interval_summary' | wc -l)" -gt 0 ]]; then
    message="Archivos de profundidad creados"
else
    message="Algo salió mal con GATK"
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=$message"
    exit 0

fi

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=$message"

# activar entorno de conda con xhmm
#source /mnt/anaconda3/bin/activate xhmm

# crear parámetro para correr xhmm y unir tablas
param1=$(for i in $(find depths/depths_fixed/ -maxdepth 1 -mindepth 1 -name "*.DATA.sample_interval_summary"); do echo -n "--GATKdepths $i "; done)

xhmm --mergeGATKdepths -o depths/depths_fixed/data/DATA.RD.txt $param1

wait

folder="depths/depths_fixed/data"

# elimina muestras y targets (exones) con profundidad de lectura (RD) o tamaño extremos, y centra los datos
xhmm --matrix -r "$folder"/DATA.RD.txt --centerData --centerType target -o "$folder"/DATA.filtered_centered.RD.txt --outputExcludedTargets "$folder"/DATA.filtered_centered.RD.txt.filtered_targets.txt --outputExcludedSamples "$folder"/DATA.filtered_centered.RD.txt.filtered_samples.txt --minTargetSize 10 --maxTargetSize 10000 --minMeanTargetRD 10 --maxMeanTargetRD 500 --minMeanSampleRD 25 --maxMeanSampleRD 200 --maxSdSampleRD 150

# calcula los componentes principales para identificar sesgos y ruido sistemático
xhmm --PCA -r "$folder"/DATA.filtered_centered.RD.txt --PCAfiles "$folder"/DATA.RD_PCA

# elimina el ruido sistemático (basado en el PCA) y reconstruye la matriz de profundidad de lectura
xhmm --normalize -r "$folder"/DATA.filtered_centered.RD.txt --PCAfiles "$folder"/DATA.RD_PCA --normalizeOutput "$folder"/DATA.PCA_normalized.txt --PCnormalizeMethod PVE_mean --PVE_mean_factor 0.7

# convierte los datos a puntajes Z por muestra y descarta targets altamente variables
xhmm --matrix -r "$folder"/DATA.PCA_normalized.txt --centerData --centerType sample --zScoreData -o "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt --outputExcludedTargets "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt.filtered_targets.txt --outputExcludedSamples "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt.filtered_samples.txt --maxSdTargetRD 30

# excluye de los datos originales crudos exactamente las mismas muestras y targets descartados en los pasos
xhmm --matrix -r "$folder"/DATA.RD.txt --excludeTargets "$folder"/DATA.filtered_centered.RD.txt.filtered_targets.txt --excludeTargets "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt.filtered_targets.txt --excludeSamples "$folder"/DATA.filtered_centered.RD.txt.filtered_samples.txt --excludeSamples "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt.filtered_samples.txt -o "$folder"/DATA.same_filtered.RD.txt

# identifica las variaciones en el número de copias utilizando el modelo oculto de Markov (HMM) sobre los datos estandarizados y crudos
xhmm --discover -p $params -r "$folder"/DATA.PCA_normalized.filtered.sample_zscores.RD.txt -R "$folder"/DATA.same_filtered.RD.txt -c "$folder"/DATA.xcnv -a "$folder"/DATA.aux_xcnv -s "$folder"/DATA

# mensaje final
if [ -s "$folder/DATA.xcnv" ]; then
    message="cnvs listos."
else
    message="Algo salió mal con xhmm."
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=$message"
    exit 0
fi


curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=$message"

# mandar archivo de cnvs
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
  -F "chat_id=${CHAT_ID}" \
  -F "document=@${folder}/DATA.xcnv"
