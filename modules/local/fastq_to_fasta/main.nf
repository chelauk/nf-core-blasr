// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FASTQ_TO_FASTA {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    // TODO nf-core: List required Conda package(s).
    //               Software MUST be pinned to channel (i.e. "bioconda"), version (i.e. "1.10").
    //               For Conda, the build (i.e. "h9402c20_2") must be EXCLUDED to support installation on different operating systems.
    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda (params.enable_conda ? "bioconda::blasr=5.3.5" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
		container "https://depot.galaxyproject.org/singularity/blasr:5.3.5--0"
    } else {
        container "quay.io/biocontainers/YOUR-TOOL-HERE"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*fasta"), emit: fasta

    script:
	def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    zcat $reads | sed -n \'1~4s/^@/>/p;2~4p\' > ${prefix}.fasta
    """
    stub:
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    touch ${prefix}.fasta
    """
}
