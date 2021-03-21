#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. *** Get timeseries channels ***
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process get_channels {
    container = params.cli_container

    output:
    file 'channels.json' into channels

    script:
    """
    #!/bin/bashlog

    /app/etl-data get-channels \
        --package-id="${params.sourcePackageId}" \
        --organization-id="${params.organizationId}" \
        --output-file="channels.json"
    """
}


/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. *** Run the exporter ***
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process run_exporter {
    container = params.export_processor_template.replace('<TYPE>', 'timeseries')

    input:
    file 'channels.json' from channels

    output:
    file 'asset.json' into asset_file

    script:
    """
    #!/bin/bashlog
    echo "- packageId: ${params.packageId}"
    echo "- userId: ${params.userId}"

    python /app/run.py \
      --channels="channels.json" \
      --package-id="${params.packageId}" \
      --user-id="${params.userId}"
    """
}


/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3. *** Generate the asset file ***
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process generate_asset_file {
  container = params.cli_container

  input:
  file 'asset.json' from asset_file

  script:
  """
  #!/bin/bashlog
  /app/etl-data create-asset \
      --asset-info=asset.json \
      --package-id=${params.packageId} \
      --organization-id=${params.organizationId}
  """
}
