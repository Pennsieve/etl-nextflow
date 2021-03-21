#!/usr/bin/env nextflow

import groovy.json.JsonOutput
import groovy.json.JsonBuilder

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

channels_json = JsonOutput.prettyPrint(new JsonBuilder(params.channels ).toString())

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Parse BFTS file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process format_parser {
    file_type = params.fileType.toLowerCase()
    container = params.import_processor_template.replace('<TYPE>',file_type)

    input:
    file input_files from s3_keys.collect { file(it) }
    file 'existing_channels.json' from channels_json

    output:
    file 'channel*.json'   into ts_channels mode flatten
    file 'channel*.ts.bin' into ts_channel_data mode flatten

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py --mode=append --channels=existing_channels.json ${arglist}"
    """
    #!/bin/bashlog
    ${cmd}
    """
}


/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Update channel on package
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

channel_pairs = ts_channels.cross(ts_channel_data){it -> it.getName().tokenize(".")[0] }

process update_channel {
    container = params.cli_container

    maxForks params.max_forks

    input:
    set file('channel_info.json'), val(ch_data_file) from channel_pairs

    output:
    set file('channel.json'), ch_data_file into created_channel

    script:
    """
    #!/bin/bashlog
    /app/etl-data set-channel \
        --channel-info=channel_info.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId} \
        --output-file=channel.json
    """
}


/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3. Write channel data to time series database
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process channel_writer {
    container = params.import_processor_template.replace('<TYPE>','channel-writer')

    maxForks params.max_forks

    input:
    set file(ch_info_file:'channel.json'), file(ch_data_file:'channel.ts.bin') from created_channel

    output:
    stdout output into result

    script:
    """
    #!/bin/bashlog
    export WRITE_MODE=APPEND
    python /app/run.py --channel=channel.json --file=channel.ts.bin
    """
}
