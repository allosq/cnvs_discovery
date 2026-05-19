# 1. Título del proyecto
**Descubrimiento Automatizado de CNVs a partir de WES (GATK4 + XHMM)**

## 2. Introducción
La identificación de Variaciones en el Número de Copias (CNV) a partir de secuenciación de exoma completo (WES) es un desafío computacional debido a los sesgos técnicos de la captura de exones y la profundidad de lectura desigual. Este proyecto implementa un pipeline bioinformático que estandariza estas profundidades y utiliza modelos estadísticos para diferenciar señales biológicas reales de ruido técnico, facilitando la investigación genómica estructural.

## 3. Objetivo
Automatizar y paralelizar el flujo de trabajo para la detección de CNVs, desde el cálculo de profundidad de cobertura hasta la normalización e identificación de variantes. El proyecto integra la preparación automática del entorno y las referencias genómicas, junto con un sistema de notificaciones vía Telegram para monitorear análisis prolongados.

## 4. Descripción general del flujo de trabajo
El análisis consta de las siguientes etapas principales:
1.  **Configuración del Entorno y Datos de Referencia:** Instalación automática de Miniconda (si no existe), despliegue del entorno con las dependencias necesarias y descarga automatizada del genoma de referencia (GRCh37/b37) junto con sus índices.
2.  **Pre-procesamiento:** Segmentación paralela de las listas de muestras para optimizar los recursos computacionales.
3.  **Cálculo de Profundidad:** Ejecución en paralelo de `DepthOfCoverage` de GATK4 sobre los intervalos del exoma.
4.  **Fusión y Filtrado (XHMM):** Integración de matrices de profundidad y eliminación de muestras o exones con valores extremos.
5.  **Normalización (PCA):** Cálculo de componentes principales y eliminación del ruido sistemático.
6.  **Z-Score y Descubrimiento (HMM):** Estandarización de las profundidades y ejecución de Modelos Ocultos de Márkov para llamar deleciones y duplicaciones.
7.  **Notificación:** Envío del estado de la corrida y del documento de resultados final al usuario a través de un bot de Telegram.

## 5. Estructura del repositorio
```text
final_project/
├── README.md                  # Documento principal del proyecto
├── run.sh                     # Script principal que ejecuta el pipeline de GATK y XHMM
├── setup.sh                   # Verifica Conda, crea el entorno y descarga el genoma
├── cnv_discovery.yml          # Archivo de configuración para reproducir el entorno Conda
├── .env                       # Variables de entorno (TOKEN y CHAT_ID de Telegram)
└── run_files/                 # Carpeta con archivos de configuración, metadatos y referencias
    ├── patients.list          # Lista de rutas a los archivos BAM/CRAM de los pacientes
    ├── params.txt             # Parámetros del modelo HMM para XHMM
    ├── intervals-Broad.human.exome.b37.list # Targets/Exones de referencia
    ├── human_g1k_v37.fasta    # Genoma de referencia (Descargado por setup.sh)
    ├── human_g1k_v37.fasta.fai# Índice del genoma (Descargado por setup.sh)
    └── human_g1k_v37.dict     # Diccionario de secuencias (Descargado por setup.sh)

