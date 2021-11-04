#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/blasr
========================================================================================
    Github : https://github.com/nf-core/blasr
    Website: https://nf-co.re/blasr
    Slack  : https://nfcore.slack.com/channels/blasr
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { BLASR_WF } from './workflows/blasr'

//
// WORKFLOW: Run main nf-core/blasr analysis pipeline
//
workflow NFCORE_BLASR {
    BLASR_WF ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_BLASR ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
