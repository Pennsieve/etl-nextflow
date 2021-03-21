#!/usr/bin/env nextflow

// VERSION: 0.1.0

process simple {
    container = "pennsieve/base-processor"

    input:
    val message from params.message

    script:
    """
    #!/bin/bashlog

    echo '${message}!'
    """
}
