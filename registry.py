registry = {
    ### Workflow ##############################################################
    # Type: workflow
    # Description:
    #     An workflow for a file being imported into the pennsieve
    #     platform
    # Key: File type
    # Value: Nextflow workflow
    ###########################################################################
    "workflow": {
        "MEF"                     : "import-timeseries",
        "EDF"                     : "import-timeseries",
        "TDMS"                    : "import-timeseries",
        "OpenEphys"               : "import-timeseries",
        "Persyst"                 : "import-timeseries",
        "NeuroExplorer"           : "import-timeseries",
        "Blackrock"               : "import-timeseries",
        "MobergSeries"            : "import-timeseries",
        "BFTS"                    : "import-timeseries",
        "Nicolet"                 : "import-timeseries",
        "MEF3"                    : "import-timeseries",
        "Feather"                 : None,
        "NEV"                     : "import-timeseries",
        "Spike2"                  : "import-timeseries",
        "MINC"                    : "import-radiological-imaging",
        "DICOM"                   : "import-radiological-imaging",
        "NIFTI"                   : "import-radiological-imaging",
        "OMETIFF"                 : "import-microscopy-imaging",
        "BRUKERTIFF"              : "import-microscopy-imaging",
        "CZI"                     : "import-microscopy-imaging",
        "ANALYZE"                 : "import-radiological-imaging",
        "MGH"                     : "import-radiological-imaging",
        "JPEG"                    : "import-standard-image",
        "JPEG2000"                : "import-standard-image",
        "PNG"                     : "import-standard-image",
        "TIFF"                    : "import-tiff-image",
        "GIF"                     : "import-standard-image",
        "WEBM"                    : "import-video-thumbnail-only",
        "OGG"                     : "import-video",
        "MOV"                     : "import-video",
        "AVI"                     : "import-video",
        "MP4"                     : "import-video",
        "CSV"                     : "import-tabular",
        "TSV"                     : "import-tabular",
        "MSExcel"                 : None,
        "Aperio"                  : "import-microscopy-imaging",
        "MSWord"                  : None,
        "PDF"                     : None,
        "Text"                    : None,
        "BFANNOT"                 : None,
        "NeuroDataWithoutBorders" : "import-hdf5-archive",
        "HDF5"                    : "import-hdf5-archive",
        "ZIP"                     : "import-zip-archive",
        "Unsupported"             : None
    },

    ### Workflow ##############################################################
    # Type: append
    # Description: A workflow used specifically for appending data to a
    #    timeseries file.
    # Key: File type
    # Value: Nextflow workflow
    ###########################################################################
    "append": {
        "BFTS"          : "append-timeseries",
        "MEF"           : "append-timeseries",
        "MEF3"          : "append-timeseries"
    },

    ### Workflow ##############################################################
    # Type: export
    # Description: A workflow used to export the data contained in a package
    #     into a different file format, resulting in a new package.
    # Key: Package type
    # Value: Nextflow workflow
    ###########################################################################
    "export": {
        "TimeSeries": "export-timeseries"
    }
}

overrides = {
        "MEF"           : "MEF2",
        "MobergSeries"  : "moberg",
        "NeuroExplorer" : "nex"
}
