#!/usr/bin/env nextflow

process simple {

    script:
    """
    echo 'Hello, World! From within a Nextflow workflow :)'
    """
}
