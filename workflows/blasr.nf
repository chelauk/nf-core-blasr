/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowBlasr.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input,
    params.multiqc_config,
    params.fasta
]

// Intialize file channels based on params, defined in the params.genomes[params.genome] scope
fasta = params.fasta ? Channel.fromPath(params.fasta).collect() : ch_dummy_file

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

//
// MODULE: Local to the pipeline
//
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions' addParams( options: [publish_files : ['tsv':'']] )

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC  } from '../modules/nf-core/modules/fastqc/main'  addParams( options: modules['fastqc'] )
include { MULTIQC } from '../modules/nf-core/modules/multiqc/main' addParams( options: multiqc_options   )

//
// MODULE: Install from local
//

include { BLASR  } from '../modules/local/blasr/main'  addParams( options: modules['blasr'] )
include { FASTQ_TO_FASTA  } from '../modules/local/fastq_to_fasta/main'  addParams( options: modules['fastqtofasta'] )

//
// MODULE: Install from nf-core
//

include { SAMTOOLS_SORT }  from '../modules/nf-core/modules/samtools/sort/main' addParams ( options: modules['samtools_sort'])
include { SAMTOOLS_INDEX } from '../modules/nf-core/modules/samtools/index/main' addParams ( options: modules['samtools_index'])
include { QUALIMAP_BAMQC } from '../modules/nf-core/modules/qualimap/bamqc/main' addParams ( options: modules['bamqc'])

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow BLASR_WF {

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        INPUT_CHECK.out.reads
    )
    ch_software_versions = ch_software_versions.mix(FASTQC.out.version.first().ifEmpty(null))

    //
    // MODULE: Run fastqtosam
    //
    //PICARD_FASTQTOSAM  (
    //    INPUT_CHECK.out.reads
    //)

    //
    // MODULE: fastq to fasta
    //
    FASTQ_TO_FASTA (
        INPUT_CHECK.out.reads
    )
    //
    // MODULE: Run blasr
    //

    BLASR (
        FASTQ_TO_FASTA.out.fasta,fasta
    )

    //
    // MODULE: Run Samtools sort and index
    //

    SAMTOOLS_SORT (
        BLASR.out.bam
    )

    SAMTOOLS_INDEX (
        SAMTOOLS_SORT.out.bam
    )

    bamqc_ch = SAMTOOLS_SORT.out.bam.cross(SAMTOOLS_INDEX.out.bai)
                                    .map{bam,bai -> [bam[0],bam[1],bai[1]]}
    //
    // MODULE: Run Bamqc
    //

    gff     = file("dummy_file.txt")
    use_gff = false

    QUALIMAP_BAMQC ( bamqc_ch, gff, use_gff )


    //
    // MODULE: Pipeline reporting
    //


    ch_software_versions
        .map { it -> if (it) [ it.baseName, it ] }
        .groupTuple()
        .map { it[1][0] }
        .flatten()
        .collect()
        .set { ch_software_versions }

    GET_SOFTWARE_VERSIONS (
        ch_software_versions.map { it }.collect()
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBlasr.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(GET_SOFTWARE_VERSIONS.out.yaml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(QUALIMAP_BAMQC.out.results.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report       = MULTIQC.out.report.toList()
    ch_software_versions = ch_software_versions.mix(MULTIQC.out.version.ifEmpty(null))
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
