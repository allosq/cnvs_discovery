#!/bin/bash

# nombre y configuración del ambiente
ENV_NAME="cnv_discovery"
YML_FILE="cnv_discovery.yml"
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"

# directorio de instalación
INSTALL_DIR="$HOME/miniconda3" 

# verificar instalación de conda
if command -v conda &> /dev/null; then
    echo "conda detectado en el sistema."
    CONDA_BASE=$(conda info --base)
elif [ -d "$INSTALL_DIR" ]; then
    echo "Conda encontrado en $INSTALL_DIR (No estaba en el PATH)."
    CONDA_BASE="$INSTALL_DIR"
else
    echo "Conda no encontrado. Iniciando descarga e instalación silenciosa..."
    
    # descargar el instalador de Miniconda de forma silenciosa (-q)
    wget -qO miniconda_installer.sh "$MINICONDA_URL"
    
    # instalar en modo batch (-b) en el directorio especificado (-p)
    bash miniconda_installer.sh -b -p "$INSTALL_DIR"
    
    # limpiar el archivo de instalación
    rm miniconda_installer.sh
    
    CONDA_BASE="$INSTALL_DIR"
    echo "Instalación de Miniconda completada."
fi

# cargar las funciones de conda en el entorno actual del script
source "$CONDA_BASE/etc/profile.d/conda.sh"

# verificar si el entorno cnv_discovery ya existe
if conda info --envs | grep -q "^$ENV_NAME "; then
    echo "El entorno '$ENV_NAME' ya existe."
    echo "Actualizando dependencias según $YML_FILE..."
    conda env update -f "$YML_FILE" --prune
else
    echo "Creando el entorno '$ENV_NAME' desde cero..."
    conda env create -f "$YML_FILE"
fi


# Activar el entorno
conda activate "$ENV_NAME"

# Comprobación rápida de los binarios
echo "Verificando herramientas de diagnóstico..."
echo "--------------------------------------------------------"
gatk --version | grep "The Genome Analysis Toolkit" || echo "GATK versión: $(gatk --version 2>&1 | head -n 1)"
xhmm --help 2>&1 | head -n 5
echo "--------------------------------------------------------"


# directorio y archivo de referencia
REF_DIR="run_files"
REF_FILE="$REF_DIR/human_g1k_v37.fasta"

# comprobar si el archivo de referencia YA existe
if [ ! -f "$REF_FILE" ]; then
    echo "El genoma de referencia no se encontró en $REF_DIR. Iniciando descarga..."

    # entrar al directorio para que wget guarde los archivos ahí
    cd "$REF_DIR" || exit

    # descargar el FASTA comprimido
    wget -q --show-progress -c http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz

    # descomprimir el archivo
    echo "Descomprimiendo el genoma de referencia..."
    gunzip -f human_g1k_v37.fasta.gz

    # descargar el índice (.fai)
    echo "Descargando el índice (.fai)..."
    wget -q --show-progress -c http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.fai

    # descargar el diccionario (.dict) necesario para GATK
    echo "Descargando el diccionario (.dict)..."
    wget -q --show-progress -c http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.dict

    # Volver al directorio principal del proyecto
    cd ..

    echo "¡Genoma de referencia y archivos auxiliares descargados y listos en $REF_DIR!"
else
    echo "El genoma de referencia ya existe en $REF_FILE. Saltando la descarga."
fi
