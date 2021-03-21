#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Parse time series file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process format_parser {
    file_type = params.fileType.toLowerCase()
    container = params.import_processor_template.replace('<TYPE>',file_type)

    input:
    file input_files from s3_keys.collect { file(it) }

    output:
    file 'channel*.json'   into ts_channels mode flatten
    file 'channel*.ts.bin' into ts_channel_data mode flatten

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py ${arglist}"
    """
    #!/bin/bashlog

    ${cmd}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Create channel on package
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

channel_pairs = ts_channels.cross(ts_channel_data){it -> it.getName().tokenize(".")[0] }

process create_channel {
    container = params.cli_container

    maxForks params.max_forks

    input:
    set file(channel_info), val(ch_data_file) from channel_pairs

    output:
    set file('channel.json'), ch_data_file into created_channel

    script:
    """
    #!/bin/bashlog

    /app/etl-data set-channel \
        --channel-info=${channel_info} \
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

    python /app/run.py --channel=channel.json --file=channel.ts.bin
    """
}
