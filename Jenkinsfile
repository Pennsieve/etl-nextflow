#!groovy
node('executor') {
  try {

    checkout scm

    def authorName = sh(returnStdout: true, script: 'git --no-pager show --format="%an" --no-patch')
    def serviceName = env.JOB_NAME.tokenize("/")[1]
    def isMain = env.BRANCH_NAME == "main"

    def commitHash = sh(returnStdout: true, script: 'git rev-parse HEAD | cut -c-7').trim()
    def imageTag = "${env.BUILD_NUMBER}-${commitHash}"

    env.IMAGE_TAG = imageTag
    env.AUTHOR_NAME = authorName
    env.SERVICE_NAME = serviceName
    env.IS_MAIN = isMain
    env.COMMIT_HASH = commitHash

    node("dev-executor") {
      ws("/tmp/etl-nextflow-${env.BRANCH_NAME}") {
        checkout scm
        stage("Tests") {
          // try {
          //   sh "TAG=${commitHash} make clean"
          //   sh "TAG=${commitHash} make test-executor"
          //   sh "TAG=${commitHash} make test"
          // } finally {
          //   sh "TAG=${commitHash} make clean"
          // }
        }
      }
    }

    if (env.IS_MAIN) {
      stage("Build And Push Image") {
        sh "TAG=latest make image"
        sh "docker tag pennsieve/nextflow:latest pennsieve/nextflow:${env.IMAGE_TAG}"
        sh "TAG=${env.IMAGE_TAG} make push"
      }
      stage("Deploy") {
        build job: "service-deploy/pennsieve-non-prod/us-east-1/dev-vpc-use1/dev/${env.SERVICE_NAME}",
                parameters: [
                        string(name: 'IMAGE_TAG', value: env.IMAGE_TAG),
                        string(name: 'TERRAFORM_ACTION', value: 'apply')
                ]
      }
    }

    slackSend(color: '#006600', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) by ${env.SERVICE_NAME}")
  } catch (e) {
    echo 'ERROR: ' + e.toString()
    sh "TAG=${env.COMMIT_HASH} make clean"
    slackSend(color: '#b20000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) by ${env.SERVICE_NAME}")
    throw e
  }
}
