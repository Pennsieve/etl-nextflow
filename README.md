# ETL Workflows

Our ETL uses [Nextflow](https://www.nextflow.io/docs/latest/index.html) to coordinate workflow execution. All workflows are defined in the Nextflow language (a subset of Groovy) and stored in `.nf` files under `/workflows`.

## Repo Structure

 * `Dockerfile`: ETL Executor image
 * `workflows/<name>.nf`: A workflow definition
 * `tests/<name>/inputs*.json`: Test input(s) for `<name>` workflow.
 * `tests/<name>/data/<file>`: Test file inputs(s) for workflow. Optional.

## ETL Executor

The executor will run Nextflow based on these environment variables:

 * `WORKFLOW_FILE`: S3 location of workflow (must be `.nf` file)
 * `MANIFEST_KEY`: S3 key of workflow input parameters (must be `.json` file)
 * `WORKING_DIR`: S3 location to serve as workflow-specific working/scratch directory.
 * `ENVIRONMENT`: Of values `prod`/`dev`/`test`

## Workflow Testing

### Set up machine for local testing

In your shell, run `sudo vim /etc/hosts` and add the following two lines to the bottom of the file:
```
127.0.0.1       local-storage-pennsieve.localhost
```
### Configure a new workflow for local testing

1. Save your `inputs*.json` file in `tests/{workflow}`.  For an upload workflow, your input will be a package manifest in json format.  Something like this:
   ```
   {
     "packageId": 1,
     "organizationId": 1,
     "userId": 1,
     "fileType": "AVI",
     "packageType": "Video",
     "files": [
       "s3://local-storage-pennsieve/import-video/data/test.avi"
     ],
     "assetDirectory": "data/video/",
     "packageNodeId": "N:package:4e8c459b-bffb-49e1-8c6a-de2d8190d84e"
   }
   ```
2. If you have the necessary S3 access, upload your test input asset(s) to the s3 path `s3://pennsieve-ops/testing-resources/etl/data/{workflow}/`.  This will allow Jenkins to access your test input.

   If you cannot access this path, then save your test asset(s) to `/tmp/local-etl-nextflow/{workflow}/` on your local machine for local testing.
3. If needed, write a SQL script to add your test packages/channels/etc. to your local postgres database.  See `tests/import-video/local-seed.sql` for an example.\
   Save your script as `local-seed.sql` under `tests/{workflow}/`\
   Tip: Make sure that your postgres entries match the data in your `inputs*.json` file.
4. Specify the job definitions (for dev/prod) and docker images (for local testing) that are used by your workflow in each profile in `nextflow.config`.

### Running local test(s)

To install Nextflow and run all the tests:

``` shell
make test
```

To run the test for a specific workflow:

```shell
make test-workflow-{name}
```
